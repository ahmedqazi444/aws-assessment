# environments/eu-west-1/outputs.tf

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = module.apigateway.cloudfront_url
}

output "api_gateway_url" {
  description = "API Gateway URL (direct, for debugging)"
  value       = module.apigateway.api_gateway_url
}

output "region" {
  description = "AWS region"
  value       = "eu-west-1"
}
