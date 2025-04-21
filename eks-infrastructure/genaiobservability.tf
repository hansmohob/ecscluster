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
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" : "sts.amazonaws.com",
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" : "system:serviceaccount:observability:observability-sa"
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
          "logs:*"
        ]
        Resource = ["${aws_cloudwatch_log_group.eks_cluster.arn}*"]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:*"
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

###Work from Monday###
# Firehose IAM Role
resource "aws_iam_role" "firehose_role" {
  name = "${var.prefix_code}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

# Firehose Policy
resource "aws_iam_role_policy" "firehose_policy" {
  name = "${var.prefix_code}-firehose-policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          aws_s3_bucket.processed_logs.arn,
          "${aws_s3_bucket.processed_logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:*"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.firehose_logs.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.eks.arn
        ]
      }
    ]
  })
}

# CloudWatch Log Group for Firehose's own logs
resource "aws_cloudwatch_log_group" "firehose_logs" {
  name              = "/aws/firehose/${var.prefix_code}-eks-logs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.eks.arn
}

# Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "eks_logs" {
  name        = "${var.prefix_code}-eks-logs"
  destination = "extended_s3"

  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn  = aws_kms_key.eks.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_role.arn
    bucket_arn          = aws_s3_bucket.processed_logs.arn
    buffering_size      = 64
    buffering_interval  = 60
    prefix              = "eks-logs/logtype=!{partitionKeyFromQuery:logtype}/namespace=!{partitionKeyFromQuery:namespace}/pod=!{partitionKeyFromQuery:pod}/container=!{partitionKeyFromQuery:container}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"

    dynamic_partitioning_configuration {
      enabled = true
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs.name
      log_stream_name = "S3Delivery"
    }

    processing_configuration {
      enabled = true

      processors {
        type = "MetadataExtraction"
        parameters {
          parameter_name  = "JsonParsingEngine"
          parameter_value = "JQ-1.6"
        }
        parameters {
          parameter_name  = "MetadataExtractionQuery"
          parameter_value = "{logtype: if .Type then .Type elif .systemd_unit then \"dataplane\" elif .kind then \"audit\" else \"application\" end, namespace: if .kubernetes.namespace_name then .kubernetes.namespace_name elif .Namespace then .Namespace elif .objectRef.namespace then .objectRef.namespace else \"unknown\" end, pod: if .kubernetes.pod_name then .kubernetes.pod_name elif .PodName then .PodName elif .FullPodName then .FullPodName else \"unknown\" end, container: if .kubernetes.container_name then .kubernetes.container_name elif .ContainerName then .ContainerName else \"system\" end}"
        }
      }
    }

    compression_format = "GZIP"
  }
}

# CloudWatch Log Subscription Role
resource "aws_iam_role" "cloudwatch_subscription" {
  name = "${var.prefix_code}-cloudwatch-subscription-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
      }
    ]
  })
}

# CloudWatch Log Subscription Policy
resource "aws_iam_role_policy" "cloudwatch_subscription" {
  name = "${var.prefix_code}-cloudwatch-subscription-policy"
  role = aws_iam_role.cloudwatch_subscription.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:*"
        ]
        Resource = [aws_kinesis_firehose_delivery_stream.eks_logs.arn]
      }
    ]
  })
}

# Log Subscription Filters
resource "aws_cloudwatch_log_subscription_filter" "eks_cluster" {
  name            = "${var.prefix_code}-eks-cluster-subscription"
  log_group_name  = aws_cloudwatch_log_group.eks_cluster.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.eks_logs.arn
  role_arn        = aws_iam_role.cloudwatch_subscription.arn
  distribution    = "Random"
}

# Subscription filters for existing Container Insights log groups
resource "aws_cloudwatch_log_subscription_filter" "container_insights" {
  name            = "${var.prefix_code}-container-insights-subscription"
  log_group_name  = "/aws/containerinsights/${var.prefix_code}-eks-cluster/application"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.eks_logs.arn
  role_arn        = aws_iam_role.cloudwatch_subscription.arn
  distribution    = "Random"
}

resource "aws_cloudwatch_log_subscription_filter" "performance" {
  name            = "${var.prefix_code}-performance-subscription"
  log_group_name  = "/aws/containerinsights/${var.prefix_code}-eks-cluster/performance"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.eks_logs.arn
  role_arn        = aws_iam_role.cloudwatch_subscription.arn
  distribution    = "Random"
}