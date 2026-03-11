# modules/apigateway/variables.tf

variable "region" {
  description = "AWS region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN for API Gateway authorizer"
  type        = string
}

variable "greeter_function_name" {
  description = "Greeter Lambda function name"
  type        = string
}

variable "greeter_invoke_arn" {
  description = "Greeter Lambda invoke ARN"
  type        = string
}

variable "dispatcher_function_name" {
  description = "Dispatcher Lambda function name"
  type        = string
}

variable "dispatcher_invoke_arn" {
  description = "Dispatcher Lambda invoke ARN"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "WAF Web ACL ARN for CloudFront"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}
