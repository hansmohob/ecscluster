output "cloudfront_url" {
  description = "URL to access code-server through CloudFront"
  value       = "https://${aws_cloudfront_distribution.code_server.domain_name}"
}

output "code_server_password" {
  description = "Initial code-server password (sensitive)"
  value       = random_password.code_server.result
  sensitive   = true
}