provider "aws" {
  region = var.Region

  default_tags {
    tags = {
      Environment = var.EnvTag
      Provisioner = "Terraform"
      Solution    = var.SolTag
    }
  }
}