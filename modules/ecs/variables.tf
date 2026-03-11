# modules/ecs/variables.tf

variable "region" {
  description = "AWS region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
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

variable "task_name" {
  description = "ECS task name"
  type        = string
  default     = "sns-publisher"
}

variable "task_image" {
  description = "Container image"
  type        = string
  default     = "amazon/aws-cli"
}

variable "task_cpu" {
  description = "Task CPU units"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Task memory in MB"
  type        = number
  default     = 512
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
