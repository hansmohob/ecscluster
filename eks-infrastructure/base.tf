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

resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.prefix_code}-eks-subnet-public${count.index + 1}-${data.aws_availability_zones.available.names[count.index]}"
    resourcetype = "network"
    "kubernetes.io/cluster/${var.prefix_code}-eks-cluster" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  count                   = 3
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = "${var.vpc_cidr_prefix}.${count.index + 10}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name         = "${var.prefix_code}-eks-subnet-private${format("%02d", count.index + 1)}-${data.aws_availability_zones.available.names[count.index]}"
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

resource "aws_eip" "nat" {
  count  = 3
  domain = "vpc"

  tags = {
    Name         = "${var.prefix_code}-eks-eip-${data.aws_availability_zones.available.names[count.index]}"
    resourcetype = "network"
  }
}

resource "aws_nat_gateway" "eks" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  depends_on = [aws_internet_gateway.eks]

  tags = {
    Name         = "${var.prefix_code}-eks-nat-public${format("%02d", count.index + 1)}-${data.aws_availability_zones.available.names[count.index]}"
    resourcetype = "network"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }

  tags = {
    Name         = "${var.prefix_code}-eks-routetable-public"
    resourcetype = "network"
  }
}

resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks[count.index].id
  }

  tags = {
    Name         = "${var.prefix_code}-eks-routetable-private${count.index + 1}-${data.aws_availability_zones.available.names[count.index]}"
    resourcetype = "network"
  }
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}