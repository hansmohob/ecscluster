# ECR repositories
module "ecr_repo_frontend" {
  source      = "./modules/ecr_repository"
  name        = "${var.prefix_code}-ecr-frontend"
  kms_key_arn = aws_kms_key.eks.arn
}

module "ecr_repo_orderservice" {
  source      = "./modules/ecr_repository"
  name        = "${var.prefix_code}-ecr-orderservice"
  kms_key_arn = aws_kms_key.eks.arn
}

module "ecr_repo_productapi" {
  source      = "./modules/ecr_repository"
  name        = "${var.prefix_code}-ecr-productapi"
  kms_key_arn = aws_kms_key.eks.arn
}

module "ecr_repo_userservice" {
  source      = "./modules/ecr_repository"
  name        = "${var.prefix_code}-ecr-userservice"
  kms_key_arn = aws_kms_key.eks.arn
}

# Create SSM parmeters to pass to service-layer git_pipeline
resource "aws_ssm_parameter" "ecr_frontend" {
  name  = "/${var.prefix_code}/ecr/frontend"
  type  = "String"
  value = module.ecr_repo_frontend.repository_url
}

resource "aws_ssm_parameter" "ecr_orderservice" {
  name  = "/${var.prefix_code}/ecr/orderservice"
  type  = "String"
  value = module.ecr_repo_orderservice.repository_url
}

resource "aws_ssm_parameter" "ecr_productapi" {
  name  = "/${var.prefix_code}/ecr/productapi"
  type  = "String"
  value = module.ecr_repo_productapi.repository_url
}

resource "aws_ssm_parameter" "ecr_userservice" {
  name  = "/${var.prefix_code}/ecr/userservice"
  type  = "String"
  value = module.ecr_repo_userservice.repository_url
}