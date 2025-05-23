#!/bin/bash

echo "INFO: Waiting for SSM agent initialization..."
until systemctl is-active --quiet amazon-ssm-agent; do
  echo "INFO: SSM agent is not ready..."
  systemctl status amazon-ssm-agent
  sleep 5
done

echo "INFO: Installing packages including CloudWatch agent"
dnf update -y -q
dnf install amazon-cloudwatch-agent -y -q

echo "INFO: Configuring CloudWatch agent..."
until aws ssm get-parameter --name /${prefix}/config/AmazonCloudWatch-linux --region ${region} &> /dev/null; do
  echo "INFO: SSM parameter is not ready..."
  sleep 5
done
aws ssm get-parameter --name /${prefix}/config/AmazonCloudWatch-linux --region ${region} --query "Parameter.Value" --output text > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

echo "INFO: Creating AWS profile for developer role..."
su - ec2-user -c "mkdir -p ~/.aws"
su - ec2-user -c "cat > ~/.aws/config << EOF
[profile developer]
role_arn = arn:aws:iam::${account_id}:role/${prefix}-iamrole-developer
credential_source = Ec2InstanceMetadata
region = ${region}
EOF"

#### START: CODE-SERVER BOOTSTRAP ####
echo "INFO: Installing code-server version ${code_server_version}..."
dnf install https://github.com/coder/code-server/releases/download/v${code_server_version}/code-server-${code_server_version}-${instance_arch}.rpm -y

echo "INFO: Configuring code-server"
mkdir -p /home/ec2-user/.config/code-server
mkdir -p /home/ec2-user/workspace
chown -R ec2-user:ec2-user /home/ec2-user/workspace

cat > /home/ec2-user/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: "$(aws secretsmanager get-secret-value --secret-id ${secret_id} --region ${region} --query SecretString --output text | jq -r .password)"
cert: false
EOF

chmod 600 /home/ec2-user/.config/code-server/config.yaml
chown -R ec2-user:ec2-user /home/ec2-user/.config

cat > /etc/systemd/system/code-server.service << EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=ec2-user
Environment=HOME=/home/ec2-user
WorkingDirectory=/home/ec2-user/workspace
ExecStart=/usr/bin/code-server --config /home/ec2-user/.config/code-server/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "INFO: Configuring code-server workspace interface..."
mkdir -p /home/ec2-user/.local/share/code-server/User/
cat >> /home/ec2-user/.local/share/code-server/User/settings.json << EOF
{
  "git.enabled": true,
  "git.path": "/usr/bin/git",
  "git.autofetch": true,
  "window.menuBarVisibility": "classic",
  "workbench.startupEditor": "none",
  "workspace.openFilesInNewWindow": "off",
  "workbench.colorTheme": "Default Dark+"
}
EOF
chown -R ec2-user:ec2-user /home/ec2-user/.local

echo "INFO: Installing Terraform..."
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
dnf install -y terraform

echo "INFO: Installing Docker..."
dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

echo "INFO: Installing extensions..."
su - ec2-user -c "code-server --install-extension amazonwebservices.amazon-q-vscode --force"
su - ec2-user -c "code-server --install-extension amazonwebservices.aws-toolkit-vscode --force"
su - ec2-user -c "code-server --install-extension hashicorp.terraform --force"
su - ec2-user -c "code-server --install-extension ms-azuretools.vscode-docker --force"

echo "INFO: Starting code-server service..."
systemctl enable code-server
systemctl start code-server

#### START: GIT-REMOTE-S3 BOOTSTRAP ####
echo "INFO: Installing git-remote-s3..."
dnf install git -y -q
dnf install -y python3 python3-pip
pip3 install boto3==1.37.18
pip3 install git-remote-s3

# Initialize git repo as ec2-user
echo "INFO: Configuring git..."
su - ec2-user -c "git config --global user.name 'EC2 User'"
su - ec2-user -c "git config --global user.email 'ec2-user@example.com'"
su - ec2-user -c "git config --global init.defaultBranch main"
# Define repo to bucket mappings
WORKSPACE="/home/ec2-user/workspace"
declare -A REPO_BUCKETS=(
  ["developer-environment"]="${git_bucket_developer-environment}"
  ["eks-infrastructure"]="${git_bucket_eks-infrastructure}"
  ["platform-config"]="${git_bucket_platform-config}"
  ["service-layer"]="${git_bucket_service-layer}"
)
# Create workspace directory and clone repo
mkdir -p $WORKSPACE
chown ec2-user:ec2-user $WORKSPACE
# TODO: Sort this bit out
echo "DEBUG: About to clone repo"
su - ec2-user -c "git clone ${github_repo} $WORKSPACE/source_repo 2>&1"
CLONE_STATUS=$?
echo "DEBUG: Clone exit status: $CLONE_STATUS"

if [ $CLONE_STATUS -ne 0 ]; then
    echo "ERROR: Git clone failed"
    echo "DEBUG: Checking workspace directory"
    ls -la $WORKSPACE
    exit 1
fi
chown -R ec2-user:ec2-user $WORKSPACE/source_repo
# Setup each repo
for repo_name in "$${!REPO_BUCKETS[@]}"; do
  echo "INFO: Setting up repository: $repo_name"
  bucket_name=$${REPO_BUCKETS[$repo_name]}
  
  su - ec2-user -c "mkdir -p $WORKSPACE/$repo_name && \
                    cd $WORKSPACE/$repo_name && \
                    cp -r $WORKSPACE/source_repo/$repo_name/* . && \
                    cp -r $WORKSPACE/source_repo/$repo_name/.* . 2>/dev/null || true && \
                    git init && \
                    git add . && \
                    git commit -m 'Initial commit' && \
                    git remote add origin s3+zip://$bucket_name/my-workspace && \
                    git push -u origin main"
  
  echo "INFO: Repository setup complete for: $repo_name"
done
# Clean up source repo
rm -rf $WORKSPACE/source_repo
#### END: GIT-REMOTE-S3 BOOTSTRAP ####

#### START: CONTAINER ADMIN BOOTSTRAP ####
echo "INFO: Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "INFO: Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${instance_arch}/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
su - ec2-user -c "echo 'source <(kubectl completion bash)' >>~/.bashrc"

echo "INFO: Installing eksctl..."
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${instance_arch}.tar.gz"
tar -xzf eksctl_Linux_${instance_arch}.tar.gz -C /tmp && rm eksctl_Linux_${instance_arch}.tar.gz
mv /tmp/eksctl /usr/local/bin
chmod +x /usr/local/bin/eksctl

echo "INFO: Installing k9s..."
curl -sLO "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${instance_arch}.tar.gz"
tar -xzf k9s_Linux_${instance_arch}.tar.gz -C /usr/local/bin && rm k9s_Linux_${instance_arch}.tar.gz
chmod +x /usr/local/bin/k9s

echo "INFO: Installing k6 pinned version..."
curl -sLO "https://github.com/grafana/k6/releases/download/v0.57.0/k6-v0.57.0-linux-${instance_arch}.tar.gz"
tar -xzf k6-v0.57.0-linux-${instance_arch}.tar.gz -C /tmp
install -o root -g root -m 0755 /tmp/k6-v0.57.0-linux-${instance_arch}/k6 /usr/local/bin/k6

echo "INFO: Installing eks-node-viewer..."
if [ "${instance_arch}" = "arm64" ]; then
    curl -sLO "https://github.com/awslabs/eks-node-viewer/releases/latest/download/eks-node-viewer_Linux_arm64"
    install -o root -g root -m 0755 eks-node-viewer_Linux_arm64 /usr/local/bin/eks-node-viewer
else
    curl -sLO "https://github.com/awslabs/eks-node-viewer/releases/latest/download/eks-node-viewer_Linux_x86_64"
    install -o root -g root -m 0755 eks-node-viewer_Linux_x86_64 /usr/local/bin/eks-node-viewer
fi
#### END: CONTAINER ADMIN BOOTSTRAP ####

#### START: SET DEVELOPER PROFILE AS DEFAULT ####
%{ if auto_set_profile }
echo "INFO: Setting up AWS profile defaults..."
su - ec2-user -c "echo 'export AWS_PROFILE=developer' >> ~/.bashrc"
su - ec2-user -c "echo 'export AWS_REGION=${region}' >> ~/.bashrc"
su - ec2-user -c "echo 'export AWS_ACCOUNTID=${account_id}' >> ~/.bashrc"
%{ endif }