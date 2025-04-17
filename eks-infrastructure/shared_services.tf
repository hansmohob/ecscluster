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