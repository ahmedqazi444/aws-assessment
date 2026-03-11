# modules/lambda/variables.tf

variable "region" {
  description = "AWS region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "lambda_source_path" {
  description = "Path to lambda source code directory"
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
  description = "SNS topic ARN"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  type        = string
}

variable "ecs_task_definition_arn" {
  description = "ECS task definition ARN"
  type        = string
}

variable "ecs_role_arns" {
  description = "ECS role ARNs for iam:PassRole"
  type        = list(string)
}

variable "subnets" {
  description = "Subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "greeter_timeout" {
  description = "Greeter Lambda timeout"
  type        = number
  default     = 30
}

variable "greeter_memory_size" {
  description = "Greeter Lambda memory size"
  type        = number
  default     = 128
}

variable "dispatcher_timeout" {
  description = "Dispatcher Lambda timeout"
  type        = number
  default     = 60
}

variable "dispatcher_memory_size" {
  description = "Dispatcher Lambda memory size"
  type        = number
  default     = 128
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
