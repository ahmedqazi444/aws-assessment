# modules/dynamodb/variables.tf

variable "region" {
  description = "AWS region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
