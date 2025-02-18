variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}
variable "Region" {
  description = "AWS region for resource deployment"
  type        = string
}

variable "EnvTag" {
  description = "Environment identifier for resource tagging (e.g., dev, prod)"
  type        = string
}

variable "SolTag" {
  description = "Solution identifier for resource grouping and tagging"
  type        = string
}