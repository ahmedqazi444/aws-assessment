# environments/global/outputs.tf
# These outputs are consumed by regional deployments via terraform_remote_state

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN for API Gateway authorizers"
  value       = module.cognito.arn
}

output "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.cognito.client_ids[0]
}

output "waf_cloudfront_arn" {
  description = "WAF Web ACL ARN for CloudFront distributions"
  value       = module.waf_cloudfront.aws_wafv2_arn
}

output "secret_name" {
  description = "Secrets Manager secret name for test user password"
  value       = aws_secretsmanager_secret.cognito_password.name
}

output "test_user_email" {
  description = "Test user email"
  value       = var.email
}
