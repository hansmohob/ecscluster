### EKS Auto Mode deployment

# IAM Role for EKS Cluster
resource "aws_iam_role" "cluster" {
  name = "${var.prefix_code}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name         = "${var.prefix_code}-eks-cluster-role"
    resourcetype = "security"
  }
}

# IAM Role for EKS Nodes
resource "aws_iam_role" "node" {
  name = "${var.prefix_code}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["sts:AssumeRole"]
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name         = "${var.prefix_code}-eks-node-role"
    resourcetype = "security"
  }
}

# Cluster IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSComputePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSBlockStoragePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSLoadBalancingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSNetworkingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.cluster.name
}

# Node IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodeMinimalPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryPullOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.node.name
}

# Deploy cluster
resource "aws_eks_cluster" "main" {
  name = "${var.prefix_code}-eks-cluster"

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.cluster.arn
  version  = "1.32"

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  bootstrap_self_managed_addons = false

  compute_config {
       enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.node.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids = [
      aws_subnet.private_subnet_01.id,
      aws_subnet.private_subnet_02.id,
      aws_subnet.private_subnet_03.id,
      aws_subnet.public_subnet_01.id,
      aws_subnet.public_subnet_02.id,
      aws_subnet.public_subnet_03.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSComputePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSBlockStoragePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSLoadBalancingPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSNetworkingPolicy,
  ]

  tags = {
    Name         = "${var.prefix_code}-eks-cluster"
    resourcetype = "compute"
  }
}

# Deploy CloudWatch Observability EKS add-on
resource "aws_eks_addon" "container_insights" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "amazon-cloudwatch-observability"
  addon_version = "v3.6.0-eksbuild.2"
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
}

# TODO: Need log retention
# resource "aws_cloudwatch_log_group" "container_insights_application" {
#  name              = "/aws/containerinsights/${var.prefix_code}-eks-cluster/application"
#  retention_in_days = 30
#  kms_key_id        = aws_kms_key.eks.arn
#}
#
#resource "aws_cloudwatch_log_group" "container_insights_performance" {
#  name              = "/aws/containerinsights/${var.prefix_code}-eks-cluster/performance"
#  retention_in_days = 30
#  kms_key_id        = aws_kms_key.eks.arn
#}


# Grants EKS cluster admin access to the developer IAM role using IAM authentication
resource "aws_eks_access_entry" "developer" {
  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix_code}-iamrole-developer"
  type              = "STANDARD"
  kubernetes_groups = ["masters"]
}

resource "aws_eks_access_policy_association" "developer_admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix_code}-iamrole-developer"

  access_scope {
    type = "cluster"
  }
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.prefix_code}-eks-cluster/cluster"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.eks.arn

  tags = {
    Name         = "${var.prefix_code}-eks-cluster-logs"
    resourcetype = "monitoring"
  }
}