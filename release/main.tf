# Sample website hosted on Amazon S3 with CloudFront distribution and WAF protection

# KMS key for encrypting S3 bucket contents

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "website_kms" {
  statement {
    # https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "kms:*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html
    sid    = "Enable CloudWatch Logs access to KMS Key"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.Region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${var.Region}:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["logs.${var.Region}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "website" {
  description             = "KMS key for website bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                 = data.aws_iam_policy_document.website_kms.json

  tags = {
    Name         = "${var.PrefixCode}-kms-website"
    resourcetype = "security"
  }
}

resource "aws_kms_alias" "website" {
  name          = "alias/${var.PrefixCode}-kms-website"
  target_key_id = aws_kms_key.website.key_id
}

# Logging bucket for S3, CloudFront and WAF logs
resource "aws_s3_bucket" "logs" {
  bucket_prefix = "${var.PrefixCode}-logs-"

  tags = {
    resourcetype = "storage"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.website.id
      sse_algorithm     = "aws:kms"
    }
  }
}

# Enable logging on website bucket
resource "aws_s3_bucket_logging" "website" {
  bucket = aws_s3_bucket.website.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-logs/"
}

# Bucket policy for logging
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3LogDelivery"
        Effect    = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/s3-logs/*"
      },
      {
        Sid       = "AllowCloudFrontLogDelivery"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/cloudfront-logs/*"
      },
      {
        Sid       = "AllowWAFLogDelivery"
        Effect    = "Allow"
        Principal = {
          Service = "wafv2.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/waf-logs/*"
      }
    ]
  })
}

# Lifecycle policy to manage log retention
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "cleanup_old_logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }

  tags = {
    resourcetype = "storage"
  }
}

# S3 bucket to store website content
resource "aws_s3_bucket" "website" {
  bucket_prefix = "${var.PrefixCode}-s3-website-"

  tags = {
    resourcetype = "storage"
  }
  lifecycle {
    # checkov:skip=CKV2_AWS_62: "Event notifications not required for static website content. Changes are managed through deployment pipeline."
    # checkov:skip=CKV_AWS_144: "Cross-region replication not required for sample website. CloudFront provides global content delivery. Consider enabling for production environments requiring disaster recovery."
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.website.id
      sse_algorithm     = "aws:kms"
    }
  }
}

# CloudFront Origin Access Control for secure S3 access
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.PrefixCode}-oac-website"
  description                       = "Origin Access Control for static website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy allowing CloudFront to access S3 content
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}

# Sample index.html file for website
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = <<EOF
<html>
<body>
<h1>Hello from Terraform!</h1>
<p>If you see this, your pipeline is working.</p>
<p>Deployed at: ${timestamp()}</p>
</body>
</html>
EOF
  content_type = "text/html"
}

# WAF web ACL to protect CloudFront distribution
resource "aws_wafv2_web_acl" "website" {
  provider    = aws.us-east-1
  name        = "${var.PrefixCode}-waf-website"
  description = "WAF Web ACL for CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled  = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "AWSManagedRulesKnownBadInputsRuleSetMetric"
      sampled_requests_enabled  = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name               = "WebACLMetric"
    sampled_requests_enabled  = true
  }

  tags = {
    resourcetype = "security"
  }
}

# Enable WAF logging
resource "aws_wafv2_web_acl_logging_configuration" "website" {
  log_destination_configs = [aws_s3_bucket.logs.arn]
  resource_arn           = aws_wafv2_web_acl.website.arn

  logging_filter {
    default_behavior = "KEEP"
  }
}

# Security headers policy for CloudFront responses
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.PrefixCode}-cloudfrontheaders-website"
  comment = "Security headers policy"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_security_policy {
      content_security_policy = "default-src 'self'"
      override                = true
    }
  }
}

# CloudFront distribution for content delivery
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = "index.html"
  web_acl_id         = aws_wafv2_web_acl.website.arn

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id               = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  logging_config {
    include_cookies = false
    bucket         = aws_s3_bucket.logs.bucket_regional_domain_name
    prefix         = "cloudfront-logs/"
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id          = "S3Origin"
    viewer_protocol_policy    = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = length(var.GeoRestriction) > 0 ? "whitelist" : "none"
      locations       = var.GeoRestriction
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = {
    resourcetype = "network"
  }

  lifecycle {
    # checkov:skip=CKV_AWS_310: "Consider implementing origin failover for production environments. Skipped for development to reduce complexity and cost."
    # checkov:skip=CKV2_AWS_42: "Using default CloudFront certificate for development environment. Custom SSL certificate recommended for production use with custom domain names."
  }
}