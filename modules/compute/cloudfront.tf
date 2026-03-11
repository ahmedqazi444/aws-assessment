# modules/compute/cloudfront.tf

#------------------------------------------------------------------------------
# CloudFront Distribution for API Gateway
# Note: CloudFront is a global service, no region argument needed
#------------------------------------------------------------------------------
module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.4.0"

  comment             = "${local.name_prefix}-api"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  wait_for_deployment = false

  # WAF association
  web_acl_id = var.waf_web_acl_arn

  # No S3 origin access control needed (we use API Gateway custom origin)
  origin_access_control = {}

  # Origin - API Gateway REST API
  # REST API requires origin_path to include the stage name
  origin = {
    api_gateway = {
      domain_name = local.api_gateway_domain
      origin_path = local.api_gateway_origin_path
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  # Default cache behavior - forward all to API Gateway
  default_cache_behavior = {
    target_origin_id       = "api_gateway"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Don't cache API responses
    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AllViewerExceptHostHeader
  }

  # Use CloudFront default certificate (*.cloudfront.net)
  viewer_certificate = {
    cloudfront_default_certificate = true
  }

  tags = var.common_tags
}
