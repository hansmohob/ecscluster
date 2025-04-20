# ECR repository for Streamlit app
module "ecr_repo_observability" {
  source      = "./modules/ecr_repository"
  name        = "${var.prefix_code}-ecr-observability"
  kms_key_arn = aws_kms_key.eks.arn
}

# SSM parameter for ECR URL
resource "aws_ssm_parameter" "ecr_observability" {
  name  = "/${var.prefix_code}/ecr/observability"
  type  = "String"
  value = module.ecr_repo_observability.repository_url
}

# IRSA for Streamlit pod
resource "aws_iam_role" "observability" {
  name = "${var.prefix_code}-observability-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}"
      }
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud": "sts.amazonaws.com",
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:observability:observability-sa"
        }
      }
    }]
  })
}

# IAM policy for the role
resource "aws_iam_role_policy" "observability" {
  name = "${var.prefix_code}-observability-policy"
  role = aws_iam_role.observability.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:DescribeLogGroups"
        ]
        Resource = ["${aws_cloudwatch_log_group.eks_cluster.arn}*"]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.processed_logs.arn,
          "${aws_s3_bucket.processed_logs.arn}/*"
        ]
      }
    ]
  })
}

# Processed Logs bucket
resource "aws_s3_bucket" "processed_logs" {
  bucket_prefix = "${var.prefix_code}-processed-logs"
  force_destroy = true

  tags = {
    Name         = "${var.prefix_code}-processed-logs"
    resourcetype = "storage"
  }
}

resource "aws_s3_bucket_versioning" "processed_logs" {
  bucket = aws_s3_bucket.processed_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_logs" {
  bucket = aws_s3_bucket.processed_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.eks.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "processed_logs" {
  bucket = aws_s3_bucket.processed_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "processed_logs_bucket" {
  statement {
    sid    = "EnforceSecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    
    resources = [
      aws_s3_bucket.processed_logs.arn,
      "${aws_s3_bucket.processed_logs.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

resource "aws_s3_bucket_policy" "processed_logs" {
  bucket = aws_s3_bucket.processed_logs.id
  policy = data.aws_iam_policy_document.processed_logs_bucket.json
}