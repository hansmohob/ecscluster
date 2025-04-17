# ECR repositories
module "ecr_repo_service1" {
  source      = "./modules/ecr_repository"
  name        = "${var.prefix_code}-ecr-frontend"
  kms_key_arn = aws_kms_key.eks.arn
}

module "ecr_repo_service2" {
  source      = "./modules/ecr_repository"
  name        = "${var.prefix_code}-ecr-orderservice"
  kms_key_arn = aws_kms_key.eks.arn
}

module "ecr_repo_service3" {
  source      = "./modules/ecr_repository"
  name        = "${var.prefix_code}-ecr-productapi"
  kms_key_arn = aws_kms_key.eks.arn
}

module "ecr_repo_service4" {
  source      = "./modules/ecr_repository"
  name        = "${var.prefix_code}-ecr-userservice"
  kms_key_arn = aws_kms_key.eks.arn
}

# Create SSM parmeter to pass to service-layer git_pipeline
resource "aws_ssm_parameter" "ecr_repositories" {
  name        = "${var.prefix_code}-ecr-repositories"
  description = "ECR Repository URLs"
  type        = "String"
  value = jsonencode({
    frontend = {
      url = module.ecr_repo_service1.repository_url
      arn = module.ecr_repo_service1.repository_arn
    }
    orderservice = {
      url = module.ecr_repo_service2.repository_url
      arn = module.ecr_repo_service2.repository_arn
    }
    productapi = {
      url = module.ecr_repo_service3.repository_url
      arn = module.ecr_repo_service3.repository_arn
    }
    userservice = {
      url = module.ecr_repo_service4.repository_url
      arn = module.ecr_repo_service4.repository_arn
    }
  })

  tags = {
    Name         = "${var.prefix_code}-ecr-repos"
    resourcetype = "compute"
  }
}