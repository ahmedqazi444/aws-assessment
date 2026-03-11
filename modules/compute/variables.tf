# modules/compute/variables.tf
variable "region" {
  description = "AWS region for this compute stack"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "email" {
  description = "Candidate email for SNS payload"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo URL for SNS payload"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for candidate verification"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN for API Gateway authorizer"
  type        = string
}

variable "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "WAF Web ACL ARN for CloudFront"
  type        = string
}

variable "lambda_source_path" {
  description = "Path to lambda source code directory"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "ecs_task_config" {
  description = "ECS task configuration for SNS publisher"
  type = object({
    name   = string
    image  = string
    cpu    = number
    memory = number
  })
  default = {
    name   = "sns-publisher"
    image  = "amazon/aws-cli"
    cpu    = 256
    memory = 512
  }
}

variable "lambda_config" {
  description = "Lambda configuration overrides"
  type = object({
    greeter = optional(object({
      timeout     = optional(number, 30)
      memory_size = optional(number, 128)
    }), {})
    dispatcher = optional(object({
      timeout     = optional(number, 60)
      memory_size = optional(number, 128)
    }), {})
  })
  default = {}
}
