
# 3 AZs public and private subnets
resource "aws_vpc" "eks" {
  cidr_block           = "${var.vpc_cidr_prefix}.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name                                                   = "${var.prefix_code}-eks-vpc"
    resourcetype                                           = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name        = "${var.prefix_code}-eks-iamrole-vpcflowlogs"
  description = "Publish flow logs to CloudWatch Logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name         = "${var.prefix_code}-eks-iamrole-VpcFlowLogs"
    resourcetype = "security"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.prefix_code}-eks-iampolicy-VpcFlowLogsPermissions"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = [
        "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/events/${var.prefix_code}-eks-vpcflowlog:*",
        "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/events/${var.prefix_code}-eks-vpcflowlog:*:*"
      ]
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/events/${var.prefix_code}-eks-vpcflowlog"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.eks.arn

  tags = {
    Name         = "${var.prefix_code}-eks-vpcflowloggroup"
    resourcetype = "monitoring"
  }
}

resource "aws_flow_log" "eks" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.eks.id

  tags = {
    Name         = "${var.prefix_code}-eks-vpcflowlog"
    resourcetype = "monitoring"
  }
}

resource "aws_subnet" "public_subnet_01" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.1.0/24"
  availability_zone       = var.az01
  map_public_ip_on_launch = false

  tags = {
    Name                                                   = "${var.prefix_code}-eks-subnet-public1-${var.az01}"
    resourcetype                                           = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                               = "1"
  }
}

resource "aws_subnet" "public_subnet_02" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.2.0/24"
  availability_zone       = var.az02
  map_public_ip_on_launch = false

  tags = {
    Name                                                   = "${var.prefix_code}-eks-subnet-public2-${var.az02}"
    resourcetype                                           = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                               = "1"
  }
}

resource "aws_subnet" "public_subnet_03" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.3.0/24"
  availability_zone       = var.az03
  map_public_ip_on_launch = false

  tags = {
    Name                                                   = "${var.prefix_code}-eks-subnet-public3-${var.az03}"
    resourcetype                                           = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                               = "1"
  }
}

resource "aws_subnet" "private_subnet_01" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.11.0/24"
  availability_zone       = var.az01
  map_public_ip_on_launch = false

  tags = {
    Name                                                   = "${var.prefix_code}-eks-subnet-private1-${var.az01}"
    resourcetype                                           = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                      = "1"
  }
}

resource "aws_subnet" "private_subnet_02" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.12.0/24"
  availability_zone       = var.az02
  map_public_ip_on_launch = false

  tags = {
    Name                                                   = "${var.prefix_code}-eks-subnet-private2-${var.az02}"
    resourcetype                                           = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                      = "1"
  }
}

resource "aws_subnet" "private_subnet_03" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.13.0/24"
  availability_zone       = var.az03
  map_public_ip_on_launch = false

  tags = {
    Name                                                   = "${var.prefix_code}-eks-subnet-private3-${var.az03}"
    resourcetype                                           = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                      = "1"
  }
}

resource "aws_internet_gateway" "eks" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name         = "${var.prefix_code}-eks-internetgateway"
    resourcetype = "network"
  }
}

# NAT Gateways
resource "aws_eip" "nat_01" {
  domain = "vpc"
  tags = {
    Name         = "${var.prefix_code}-eks-eip-${var.az01}"
    resourcetype = "network"
  }
}

resource "aws_eip" "nat_02" {
  domain = "vpc"
  tags = {
    Name         = "${var.prefix_code}-eks-eip-${var.az02}"
    resourcetype = "network"
  }
}

resource "aws_eip" "nat_03" {
  domain = "vpc"
  tags = {
    Name         = "${var.prefix_code}-eks-eip-${var.az03}"
    resourcetype = "network"
  }
}

resource "aws_nat_gateway" "nat_01" {
  allocation_id = aws_eip.nat_01.id
  subnet_id     = aws_subnet.public_subnet_01.id
  depends_on    = [aws_internet_gateway.eks]

  tags = {
    Name         = "${var.prefix_code}-eks-nat-public1-${var.az01}"
    resourcetype = "network"
  }
}

resource "aws_nat_gateway" "nat_02" {
  allocation_id = aws_eip.nat_02.id
  subnet_id     = aws_subnet.public_subnet_02.id
  depends_on    = [aws_internet_gateway.eks]

  tags = {
    Name         = "${var.prefix_code}-eks-nat-public2-${var.az02}"
    resourcetype = "network"
  }
}

resource "aws_nat_gateway" "nat_03" {
  allocation_id = aws_eip.nat_03.id
  subnet_id     = aws_subnet.public_subnet_03.id
  depends_on    = [aws_internet_gateway.eks]

  tags = {
    Name         = "${var.prefix_code}-eks-nat-public3-${var.az03}"
    resourcetype = "network"
  }
}

resource "aws_route_table" "public_01" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }

  tags = {
    Name         = "${var.prefix_code}-eks-routetable-public1-${var.az01}"
    resourcetype = "network"
  }
}

resource "aws_route_table" "public_02" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }

  tags = {
    Name         = "${var.prefix_code}-eks-routetable-public2-${var.az02}"
    resourcetype = "network"
  }
}

resource "aws_route_table" "public_03" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }

  tags = {
    Name         = "${var.prefix_code}-eks-routetable-public3-${var.az03}"
    resourcetype = "network"
  }
}

resource "aws_route_table" "private_01" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_01.id
  }

  tags = {
    Name         = "${var.prefix_code}-eks-routetable-private1-${var.az01}"
    resourcetype = "network"
  }
}

resource "aws_route_table" "private_02" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_02.id
  }

  tags = {
    Name         = "${var.prefix_code}-eks-routetable-private2-${var.az02}"
    resourcetype = "network"
  }
}

resource "aws_route_table" "private_03" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_03.id
  }

  tags = {
    Name         = "${var.prefix_code}-eks-routetable-private3-${var.az03}"
    resourcetype = "network"
  }
}

resource "aws_route_table_association" "public_01" {
  subnet_id      = aws_subnet.public_subnet_01.id
  route_table_id = aws_route_table.public_01.id
}

resource "aws_route_table_association" "public_02" {
  subnet_id      = aws_subnet.public_subnet_02.id
  route_table_id = aws_route_table.public_02.id
}

resource "aws_route_table_association" "public_03" {
  subnet_id      = aws_subnet.public_subnet_03.id
  route_table_id = aws_route_table.public_03.id
}

resource "aws_route_table_association" "private_01" {
  subnet_id      = aws_subnet.private_subnet_01.id
  route_table_id = aws_route_table.private_01.id
}

resource "aws_route_table_association" "private_02" {
  subnet_id      = aws_subnet.private_subnet_02.id
  route_table_id = aws_route_table.private_02.id
}

resource "aws_route_table_association" "private_03" {
  subnet_id      = aws_subnet.private_subnet_03.id
  route_table_id = aws_route_table.private_03.id
}

### VPC Peering to Developer Environment allowing access to EKS cluster

# Get the CodeBuild VPC
data "aws_vpc" "codebuild" {
  tags = {
    Name = "${var.prefix_code}-vpc01"
  }
}

# Get the CodeBuild route table
data "aws_route_table" "codebuild" {
  tags = {
    Name = "${var.prefix_code}-routetable-private1"
  }
}

# Create VPC peering
resource "aws_vpc_peering_connection" "codebuild_eks" {
  vpc_id      = aws_vpc.eks.id
  peer_vpc_id = data.aws_vpc.codebuild.id
  auto_accept = true

  tags = {
    Name = "${var.prefix_code}-vpc-peering"
  }
}

# Add routes from EKS private subnets to CodeBuild VPC
resource "aws_route" "eks_to_codebuild_1" {
  route_table_id            = aws_route_table.private_01.id
  destination_cidr_block    = data.aws_vpc.codebuild.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.codebuild_eks.id
}

resource "aws_route" "eks_to_codebuild_2" {
  route_table_id            = aws_route_table.private_02.id
  destination_cidr_block    = data.aws_vpc.codebuild.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.codebuild_eks.id
}

resource "aws_route" "eks_to_codebuild_3" {
  route_table_id            = aws_route_table.private_03.id
  destination_cidr_block    = data.aws_vpc.codebuild.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.codebuild_eks.id
}

# Add route from CodeBuild to EKS
resource "aws_route" "codebuild_to_eks" {
  route_table_id            = data.aws_route_table.codebuild.id
  destination_cidr_block    = aws_vpc.eks.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.codebuild_eks.id
}

# Allow all traffic from Developer Environment to EKS Cluster
resource "aws_security_group_rule" "eks_api_ingress_from_dev_vpc" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  cidr_blocks       = ["10.180.0.0/16"] # Dev VPC CIDR TODO: replace with variable
  description       = "Allow all traffic from developer VPC"
}