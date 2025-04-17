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