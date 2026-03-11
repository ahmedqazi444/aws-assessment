# environments/eu-west-1/main.tf
# Regional compute infrastructure

locals {
  region = "eu-west-1"

  common_tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
    Region      = local.region
  }

  lambda_config = {
    greeter = {
      timeout     = 30
      memory_size = 128
    }
    dispatcher = {
      timeout     = 60
      memory_size = 128
    }
  }

  ecs_task_config = {
    name   = "sns-publisher"
    image  = "amazon/aws-cli"
    cpu    = 256
    memory = 512
  }
}

#------------------------------------------------------------------------------
# COMPUTE MODULE
#------------------------------------------------------------------------------
module "compute" {
  source = "../../modules/compute"

  region       = local.region
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr

  # Candidate/SNS configuration
  email         = var.email
  github_repo   = var.github_repo
  sns_topic_arn = var.sns_topic_arn

  # From global state or variables
  cognito_user_pool_arn       = local.cognito_user_pool_arn
  cognito_user_pool_client_id = local.cognito_client_id
  waf_web_acl_arn             = local.waf_cloudfront_arn

  # Lambda configuration
  lambda_source_path = "${path.module}/../../lambda"
  lambda_config      = local.lambda_config

  # ECS configuration
  ecs_task_config = local.ecs_task_config

  # Tags
  common_tags = local.common_tags
}
