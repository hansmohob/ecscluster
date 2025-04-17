variable "prefix_code" {
  type        = string
  description = "Prefix for resource names"
}
variable "region" {
  type        = string
  description = "AWS region"
}
variable "az01" {
  description = "Availability Zone 1"
  type        = string
}
variable "az02" {
  description = "Availability Zone 2"
  type        = string
}
variable "az03" {
  description = "Availability Zone 2"
  type        = string
}
variable "environment_tag" {
  type        = string
  description = "Environment identifier for resource tagging e.g. dev, prod"
}
variable "solution_tag" {
  type        = string
  description = "Solution name tag for resource groups"
}
variable "vpc_cidr_prefix" {
  type        = string
  description = "First two octets of VPC CIDR (e.g., 10.0)"
}
variable "region_alb_account_ids" {
  type        = map(string)
  description = "ALB account IDs by region for S3 bucket policy"
  default = {
    "ap-northeast-1" = "582318560864"
    "ap-northeast-2" = "600734575887"
    "ap-northeast-3" = "383597477331"
    "ap-south-1"     = "718504428378"
    "ap-southeast-1" = "114774131450"
    "ap-southeast-2" = "783225319266"
    "ca-central-1"   = "985666609251"
    "eu-central-1"   = "054676820928"
    "eu-north-1"     = "897822967062"
    "eu-west-1"      = "156460612806"
    "eu-west-2"      = "652711504416"
    "eu-west-3"      = "009996457667"
    "sa-east-1"      = "507241528517"
    "us-east-1"      = "127311923021"
    "us-east-2"      = "033677994240"
    "us-west-1"      = "027434742980"
    "us-west-2"      = "797873946194"
  }
}
variable "cloudfront_prefix_lists" {
  type        = map(string)
  description = "CloudFront Prefix List IDs by region"
  default = {
    "ap-northeast-1" = "pl-58a04531"
    "ap-northeast-2" = "pl-22a6434b"
    "ap-northeast-3" = "pl-31a14458"
    "ap-south-1"     = "pl-9aa247f3"
    "ap-southeast-1" = "pl-31a34658"
    "ap-southeast-2" = "pl-b8a742d1"
    "ca-central-1"   = "pl-38a64351"
    "eu-central-1"   = "pl-a3a144ca"
    "eu-north-1"     = "pl-fab65393"
    "eu-west-1"      = "pl-4fa04526"
    "eu-west-2"      = "pl-93a247fa"
    "eu-west-3"      = "pl-75b1541c"
    "sa-east-1"      = "pl-5da64334"
    "us-east-1"      = "pl-3b927c52"
    "us-east-2"      = "pl-b6a144df"
    "us-west-1"      = "pl-4ea04527"
    "us-west-2"      = "pl-82a045eb"
  }
}