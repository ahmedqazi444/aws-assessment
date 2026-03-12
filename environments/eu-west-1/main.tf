# environments/eu-west-1/main.tf

locals {
  region      = "eu-west-1"
  name_prefix = "${var.project_name}-${local.region}"

  common_tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
    Region      = local.region
  }
}

module "vpc" {
  source = "../../modules/vpc"

  region      = local.region
  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  tags        = local.common_tags
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  region      = local.region
  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "ecs" {
  source = "../../modules/ecs"

  region        = local.region
  name_prefix   = local.name_prefix
  email         = var.email
  github_repo   = var.github_repo
  sns_topic_arn = var.sns_topic_arn
  tags          = local.common_tags
}

module "lambda" {
  source = "../../modules/lambda"

  region             = local.region
  name_prefix        = local.name_prefix
  lambda_source_path = "${path.module}/../../lambda"

  email         = var.email
  github_repo   = var.github_repo
  sns_topic_arn = var.sns_topic_arn

  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn

  ecs_cluster_arn         = module.ecs.cluster_arn
  ecs_task_definition_arn = module.ecs.task_definition_arn
  ecs_role_arns           = [module.ecs.task_role_arn, module.ecs.execution_role_arn]

  subnets           = module.vpc.public_subnets
  security_group_id = module.vpc.ecs_security_group_id

  tags = local.common_tags
}

module "apigateway" {
  source = "../../modules/apigateway"

  region      = local.region
  name_prefix = local.name_prefix

  cognito_user_pool_arn = local.cognito_user_pool_arn

  greeter_function_name = module.lambda.greeter_function_name
  greeter_invoke_arn    = module.lambda.greeter_invoke_arn

  dispatcher_function_name = module.lambda.dispatcher_function_name
  dispatcher_invoke_arn    = module.lambda.dispatcher_invoke_arn

  waf_web_acl_arn = local.waf_cloudfront_arn

  tags = local.common_tags
}
