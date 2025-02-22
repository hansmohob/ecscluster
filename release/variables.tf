variable "PrefixCode" {
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
variable "GeoRestriction" {
  description = "List of ISO Alpha-2 codes to restrict access https://www.iso.org/obp/ui/#search e.g. "GB", "IE", "US" or leave blank for no restriction
  type        = list(string)
  default     = []
}