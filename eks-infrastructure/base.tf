data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_resourcegroups_group" "eks" {
  name        = "${var.prefix_code}-eks-resources"
  description = "EKS Environment Resources"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "solution"
          Values = [var.solution_tag]
        }
      ]
    })
    type = "TAG_FILTERS_1_0"
  }

  tags = {
    Name         = "${var.prefix_code}-eks-resources"
    resourcetype = "management"
  }
}

resource "aws_kms_key" "eks" {
  description             = "EKS encryption key for AWS services"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Enable Cloudwatch access to KMS Key for VPC log group"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = {
    resourcetype = "security"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.prefix_code}-eks-kms-cmk"
  target_key_id = aws_kms_key.eks.key_id
}

resource "aws_vpc" "eks" {
  cidr_block           = "${var.vpc_cidr_prefix}.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name         = "${var.prefix_code}-eks-vpc"
    resourcetype = "network"
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
    Name         = "${var.prefix_code}-eks-subnet-public1-${var.az01}"
    resourcetype = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_subnet_02" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.2.0/24"
  availability_zone       = var.az02
  map_public_ip_on_launch = false

  tags = {
    Name         = "${var.prefix_code}-eks-subnet-public2-${var.az02}"
    resourcetype = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_subnet_03" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.3.0/24"
  availability_zone       = var.az03
  map_public_ip_on_launch = false

  tags = {
    Name         = "${var.prefix_code}-eks-subnet-public3-${var.az03}"
    resourcetype = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private_subnet_01" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.11.0/24"
  availability_zone       = var.az01
  map_public_ip_on_launch = false

  tags = {
    Name         = "${var.prefix_code}-eks-subnet-private1-${var.az01}"
    resourcetype = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private_subnet_02" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.12.0/24"
  availability_zone       = var.az02
  map_public_ip_on_launch = false

  tags = {
    Name         = "${var.prefix_code}-eks-subnet-private2-${var.az02}"
    resourcetype = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private_subnet_03" {
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.13.0/24"
  availability_zone       = var.az03
  map_public_ip_on_launch = false

  tags = {
    Name         = "${var.prefix_code}-eks-subnet-private3-${var.az03}"
    resourcetype = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
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