provider "aws" {
  region = "eu-west-2"
}

# S3 bucket for website hosting
resource "aws_s3_bucket" "website" {
  bucket_prefix = "demo-website-"
}

# Enable website hosting
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }
}

# Upload index.html
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.website.id
  key    = "index.html"
  content = <<EOF
<html>
<body>
<h1>Hello from Terraform!</h1>
<p>If you see this, your pipeline is working!</p>
<p>Deployed at: ${timestamp()}</p>
</body>
</html>
EOF
  content_type = "text/html"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website" {
  enabled = true
  
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3Origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "website_url" {
  value = aws_cloudfront_distribution.website.domain_name
}