# modules/apigateway/outputs.tf

output "api_gateway_url" {
  description = "API Gateway URL (direct, for debugging)"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${module.cloudfront.cloudfront_distribution_domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.cloudfront_distribution_id
}
