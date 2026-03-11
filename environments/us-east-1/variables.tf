# environments/us-east-1/variables.tf

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

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "email" {
  description = "Candidate email for SNS payload"
  type        = string
  default     = "ahmed_qazi444@hotmail.com"
}

variable "github_repo" {
  description = "GitHub repo URL for SNS payload"
  type        = string
  default     = "https://github.com/ahmedqazi444/aws-assessment"
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for candidate verification (set via GitHub secrets)"
  type        = string
}

#------------------------------------------------------------------------------
# State Configuration
#------------------------------------------------------------------------------
variable "state_bucket" {
  description = "S3 bucket for terraform state"
  type        = string
  default     = "unleash-assessment-tfstate-003767002475"
}
