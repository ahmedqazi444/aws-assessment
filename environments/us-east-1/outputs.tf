# environments/us-east-1/outputs.tf

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = module.compute.cloudfront_url
}

output "api_gateway_url" {
  description = "API Gateway URL (direct, for debugging)"
  value       = module.compute.api_gateway_url
}

output "region" {
  description = "AWS region"
  value       = "us-east-1"
}
