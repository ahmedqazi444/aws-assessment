# environments/global/main.tf
# Global resources shared across all regions

locals {
  waf_common_rules = [
    {
      name     = "rate-limit"
      priority = 0
      action   = "block"
      rate_based_statement = {
        limit                 = 500
        aggregate_key_type    = "IP"
        evaluation_window_sec = 300
      }
      visibility_config = {
        cloudwatch_metrics_enabled = "true"
        sampled_requests_enabled   = "true"
        metric_name                = "${var.project_name}-rate-limit"
      }
    },
    {
      name            = "aws-managed-common"
      priority        = 1
      override_action = "none"
      managed_rule_group_statement = {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
      visibility_config = {
        cloudwatch_metrics_enabled = "true"
        sampled_requests_enabled   = "true"
        metric_name                = "${var.project_name}-common-rules"
      }
    },
    {
      name            = "aws-managed-known-bad-inputs"
      priority        = 2
      override_action = "none"
      managed_rule_group_statement = {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
      visibility_config = {
        cloudwatch_metrics_enabled = "true"
        sampled_requests_enabled   = "true"
        metric_name                = "${var.project_name}-known-bad-inputs"
      }
    }
  ]
}

#------------------------------------------------------------------------------
# COGNITO USER POOL
#------------------------------------------------------------------------------
module "cognito" {
  source  = "lgallard/cognito-user-pool/aws"
  version = "4.0.0"

  user_pool_name      = "${var.project_name}-user-pool"
  deletion_protection = "INACTIVE"

  password_policy = {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
    password_history_size            = 0
  }

  auto_verified_attributes = ["email"]

  recovery_mechanisms = [
    {
      name     = "verified_email"
      priority = 1
    }
  ]

  schemas = [
    {
      name                     = "email"
      attribute_data_type      = "String"
      required                 = true
      mutable                  = true
      developer_only_attribute = false
      string_attribute_constraints = {
        min_length = 5
        max_length = 256
      }
    }
  ]

  clients = [
    {
      name                          = "${var.project_name}-client"
      generate_secret               = false
      explicit_auth_flows           = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
      supported_identity_providers  = ["COGNITO"]
      prevent_user_existence_errors = "ENABLED"
      enable_token_revocation       = true
      access_token_validity         = 1
      id_token_validity             = 1
      refresh_token_validity        = 30
      token_validity_units = {
        access_token  = "hours"
        id_token      = "hours"
        refresh_token = "days"
      }
    }
  ]

  tags = {
    Project     = var.project_name
    Environment = "dev"
  }
}

#------------------------------------------------------------------------------
# TEST USER + PASSWORD
#------------------------------------------------------------------------------
resource "random_password" "cognito_user" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "aws_secretsmanager_secret" "cognito_password" {
  name                    = "${var.project_name}-cognito-test-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "cognito_password" {
  secret_id     = aws_secretsmanager_secret.cognito_password.id
  secret_string = random_password.cognito_user.result
}

resource "aws_cognito_user" "test" {
  user_pool_id = module.cognito.id
  username     = var.email
  password     = random_password.cognito_user.result

  attributes = {
    email          = var.email
    email_verified = "true"
  }

  lifecycle {
    ignore_changes = [password]
  }
}
module "waf_cloudfront" {
  source  = "aws-ss/wafv2/aws"
  version = "4.1.3"

  name           = "${var.project_name}-cloudfront-waf"
  scope          = "CLOUDFRONT"
  default_action = "allow"

  visibility_config = {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "${var.project_name}-cloudfront-waf"
  }

  rule                        = local.waf_common_rules
  resource_arn                = []
  enabled_web_acl_association = false

  tags = {
    Project     = var.project_name
    Environment = "dev"
    Purpose     = "cloudfront-protection"
  }
}

#------------------------------------------------------------------------------
# WAF - COGNITO (REGIONAL scope)
#------------------------------------------------------------------------------
module "waf_cognito" {
  source  = "aws-ss/wafv2/aws"
  version = "4.1.3"

  name           = "${var.project_name}-cognito-waf"
  scope          = "REGIONAL"
  default_action = "allow"

  visibility_config = {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "${var.project_name}-cognito-waf"
  }

  rule                        = local.waf_common_rules
  resource_arn                = [module.cognito.arn]
  enabled_web_acl_association = true

  tags = {
    Project     = var.project_name
    Environment = "dev"
    Purpose     = "cognito-protection"
  }
}
