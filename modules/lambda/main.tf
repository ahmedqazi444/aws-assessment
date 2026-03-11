# modules/lambda/main.tf

locals {
  lambda_defaults = {
    runtime      = "python3.12"
    architecture = "arm64"
  }

  greeter_config = merge(local.lambda_defaults, {
    timeout     = var.greeter_timeout
    memory_size = var.greeter_memory_size
  })

  dispatcher_config = merge(local.lambda_defaults, {
    timeout     = var.dispatcher_timeout
    memory_size = var.dispatcher_memory_size
  })
}

#------------------------------------------------------------------------------
# Lambda Package Archives
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
#------------------------------------------------------------------------------
module "lambda_greeter" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.7.0"

  region = var.region

  function_name = "${var.name_prefix}-greeter"
  description   = "Greeter Lambda - writes to DynamoDB and publishes to SNS"
  handler       = "index.handler"
  runtime       = local.greeter_config.runtime
  architectures = [local.greeter_config.architecture]
  timeout       = local.greeter_config.timeout
  memory_size   = local.greeter_config.memory_size

  create_package         = false
  local_existing_package = data.archive_file.greeter.output_path

  environment_variables = {
    DYNAMODB_TABLE = var.dynamodb_table_name
    SNS_TOPIC_ARN  = var.sns_topic_arn
    EMAIL          = var.email
    GITHUB_REPO    = var.github_repo
  }

  attach_policy_statements = true
  policy_statements = {
    dynamodb = {
      effect    = "Allow"
      actions   = ["dynamodb:PutItem"]
      resources = [var.dynamodb_table_arn]
    }
    sns = {
      effect    = "Allow"
      actions   = ["sns:Publish"]
      resources = [var.sns_topic_arn]
    }
  }

  cloudwatch_logs_retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-greeter"
  })
}

#------------------------------------------------------------------------------
# Dispatcher Lambda
#------------------------------------------------------------------------------
module "lambda_dispatcher" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.7.0"

  region = var.region

  function_name = "${var.name_prefix}-dispatcher"
  description   = "Dispatcher Lambda - runs ECS task"
  handler       = "index.handler"
  runtime       = local.dispatcher_config.runtime
  architectures = [local.dispatcher_config.architecture]
  timeout       = local.dispatcher_config.timeout
  memory_size   = local.dispatcher_config.memory_size

  create_package         = false
  local_existing_package = data.archive_file.dispatcher.output_path

  environment_variables = {
    ECS_CLUSTER_ARN     = var.ecs_cluster_arn
    ECS_TASK_DEFINITION = var.ecs_task_definition_arn
    SUBNETS             = join(",", var.subnets)
    SECURITY_GROUP      = var.security_group_id
  }

  attach_policy_statements = true
  policy_statements = {
    ecs = {
      effect    = "Allow"
      actions   = ["ecs:RunTask"]
      resources = [var.ecs_task_definition_arn]
    }
    iam_pass_role = {
      effect    = "Allow"
      actions   = ["iam:PassRole"]
      resources = var.ecs_role_arns
    }
  }

  cloudwatch_logs_retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-dispatcher"
  })
}
