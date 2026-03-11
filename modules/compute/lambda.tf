# modules/compute/lambda.tf

#------------------------------------------------------------------------------
# Lambda Package Archives
# Pre-built using archive_file for consistent hashes between plan and apply
#------------------------------------------------------------------------------
data "archive_file" "greeter" {
  type        = "zip"
  source_dir  = "${var.lambda_source_path}/greeter"
  output_path = "${path.module}/builds/greeter-${var.region}.zip"
}

data "archive_file" "dispatcher" {
  type        = "zip"
  source_dir  = "${var.lambda_source_path}/dispatcher"
  output_path = "${path.module}/builds/dispatcher-${var.region}.zip"
}

#------------------------------------------------------------------------------
# Greeter Lambda
# Writes greeting to DynamoDB and publishes to SNS (if enabled)
#------------------------------------------------------------------------------
module "lambda_greeter" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.7.0"

  # Region meta-argument (AWS Provider 6.0+)
  region = var.region

  function_name = "${local.name_prefix}-greeter"
  description   = "Greeter Lambda - writes to DynamoDB and publishes to SNS"
  handler       = "index.handler"
  runtime       = local.greeter_config.runtime
  architectures = [local.greeter_config.architecture]
  timeout       = local.greeter_config.timeout
  memory_size   = local.greeter_config.memory_size

  # Use pre-built package for consistent hashes in CI/CD
  create_package         = false
  local_existing_package = data.archive_file.greeter.output_path

  environment_variables = {
    DYNAMODB_TABLE = module.dynamodb_table.dynamodb_table_id
    SNS_TOPIC_ARN  = var.sns_topic_arn
    SEND_SNS       = tostring(var.send_sns)
    EMAIL          = var.email
    GITHUB_REPO    = var.github_repo
  }

  attach_policy_statements = true
  policy_statements = {
    dynamodb = {
      effect    = "Allow"
      actions   = ["dynamodb:PutItem"]
      resources = [module.dynamodb_table.dynamodb_table_arn]
    }
    sns = {
      effect    = "Allow"
      actions   = ["sns:Publish"]
      resources = [length(trimspace(var.sns_topic_arn)) > 0 ? var.sns_topic_arn : "arn:aws:sns:us-east-1:000000000000:dummy-topic"]
    }
  }

  cloudwatch_logs_retention_in_days = local.cloudwatch_defaults.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-greeter"
  })
}

#------------------------------------------------------------------------------
# Dispatcher Lambda
# Triggers ECS Fargate task to publish SNS message
#------------------------------------------------------------------------------
module "lambda_dispatcher" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.7.0"

  # Region meta-argument (AWS Provider 6.0+)
  region = var.region

  function_name = "${local.name_prefix}-dispatcher"
  description   = "Dispatcher Lambda - runs ECS task"
  handler       = "index.handler"
  runtime       = local.dispatcher_config.runtime
  architectures = [local.dispatcher_config.architecture]
  timeout       = local.dispatcher_config.timeout
  memory_size   = local.dispatcher_config.memory_size

  # Use pre-built package for consistent hashes in CI/CD
  create_package         = false
  local_existing_package = data.archive_file.dispatcher.output_path

  environment_variables = {
    ECS_CLUSTER_ARN     = module.ecs_cluster.arn
    ECS_TASK_DEFINITION = aws_ecs_task_definition.sns_publisher.arn
    SUBNETS             = join(",", module.vpc.public_subnets)
    SECURITY_GROUP      = aws_security_group.ecs.id
  }

  attach_policy_statements = true
  policy_statements = {
    ecs = {
      effect    = "Allow"
      actions   = ["ecs:RunTask"]
      resources = [aws_ecs_task_definition.sns_publisher.arn]
    }
    iam_pass_role = {
      effect    = "Allow"
      actions   = ["iam:PassRole"]
      resources = [module.ecs_task_role.iam_role_arn, module.ecs_execution_role.iam_role_arn]
    }
  }

  cloudwatch_logs_retention_in_days = local.cloudwatch_defaults.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-dispatcher"
  })
}
