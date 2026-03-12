# environments/global/variables.tf
# PR flow test

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "unleash"
}

variable "email" {
  description = "Candidate email for Cognito user"
  type        = string
  default     = "ahmed_qazi444@hotmail.com"

  validation {
    condition     = can(regex("^[\\w.-]+@[\\w.-]+\\.[a-zA-Z]{2,}$", var.email))
    error_message = "Must be a valid email address."
  }
}
