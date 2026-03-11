# modules/compute/apigateway.tf

#------------------------------------------------------------------------------
# API Gateway Account Settings - CloudWatch Logging Role
# Required for access logging on API Gateway stages
#------------------------------------------------------------------------------
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${local.name_prefix}-apigw-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  region              = var.region
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn

  depends_on = [aws_iam_role_policy_attachment.api_gateway_cloudwatch]
}

#------------------------------------------------------------------------------
# API Gateway REST API (v1) with COGNITO_USER_POOLS Authorizer
# Using REST API to enable native Cognito Authorizer integration
#------------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "main" {
  region      = var.region
  name        = "${local.name_prefix}-api"
  description = "Unleash Live assessment API - ${var.region}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.common_tags
}

#------------------------------------------------------------------------------
# Cognito Authorizer - Points directly to us-east-1 Cognito User Pool
#------------------------------------------------------------------------------
resource "aws_api_gateway_authorizer" "cognito" {
  region          = var.region
  name            = "${local.name_prefix}-cognito-auth"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

#------------------------------------------------------------------------------
# /greet Resource and Method
#------------------------------------------------------------------------------
resource "aws_api_gateway_resource" "greet" {
  region      = var.region
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "greet"
}

resource "aws_api_gateway_method" "greet" {
  region        = var.region
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.greet.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "greet" {
  region                  = var.region
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.greet.id
  http_method             = aws_api_gateway_method.greet.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_greeter.lambda_function_invoke_arn
}

#------------------------------------------------------------------------------
# /dispatch Resource and Method
#------------------------------------------------------------------------------
resource "aws_api_gateway_resource" "dispatch" {
  region      = var.region
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "dispatch"
}

resource "aws_api_gateway_method" "dispatch" {
  region        = var.region
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.dispatch.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "dispatch" {
  region                  = var.region
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.dispatch.id
  http_method             = aws_api_gateway_method.dispatch.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_dispatcher.lambda_function_invoke_arn
}

#------------------------------------------------------------------------------
# CORS Support - OPTIONS methods for preflight requests
#------------------------------------------------------------------------------
resource "aws_api_gateway_method" "greet_options" {
  region        = var.region
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.greet.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "greet_options" {
  region      = var.region
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.greet.id
  http_method = aws_api_gateway_method.greet_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "greet_options" {
  region      = var.region
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.greet.id
  http_method = aws_api_gateway_method.greet_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "greet_options" {
  region      = var.region
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.greet.id
  http_method = aws_api_gateway_method.greet_options.http_method
  status_code = aws_api_gateway_method_response.greet_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_method" "dispatch_options" {
  region        = var.region
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.dispatch.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "dispatch_options" {
  region      = var.region
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.dispatch.id
  http_method = aws_api_gateway_method.dispatch_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "dispatch_options" {
  region      = var.region
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.dispatch.id
  http_method = aws_api_gateway_method.dispatch_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "dispatch_options" {
  region      = var.region
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.dispatch.id
  http_method = aws_api_gateway_method.dispatch_options.http_method
  status_code = aws_api_gateway_method_response.dispatch_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

#------------------------------------------------------------------------------
# Deployment and Stage
#------------------------------------------------------------------------------
resource "aws_api_gateway_deployment" "main" {
  region      = var.region
  rest_api_id = aws_api_gateway_rest_api.main.id

  depends_on = [
    aws_api_gateway_integration.greet,
    aws_api_gateway_integration.dispatch,
    aws_api_gateway_integration.greet_options,
    aws_api_gateway_integration.dispatch_options,
  ]

  # Force new deployment when any method/integration changes
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.greet.id,
      aws_api_gateway_resource.dispatch.id,
      aws_api_gateway_method.greet.id,
      aws_api_gateway_method.dispatch.id,
      aws_api_gateway_integration.greet.id,
      aws_api_gateway_integration.dispatch.id,
      aws_api_gateway_authorizer.cognito.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  region        = var.region
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "prod"

  xray_tracing_enabled = true

  # Ensure CloudWatch role is configured before enabling logging
  depends_on = [aws_api_gateway_account.main]

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      requestTime    = "$context.requestTime"
    })
  }

  tags = var.common_tags
}

#------------------------------------------------------------------------------
# Stage Throttling Settings
#------------------------------------------------------------------------------
resource "aws_api_gateway_method_settings" "all" {
  region      = var.region
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = 1000
    throttling_rate_limit  = 500
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false
  }
}

#------------------------------------------------------------------------------
# CloudWatch Log Group for API Gateway Access Logs
#------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "api_access" {
  region            = var.region
  name              = "/aws/apigateway/${local.name_prefix}-api"
  retention_in_days = local.cloudwatch_defaults.log_retention_days

  tags = var.common_tags
}

#------------------------------------------------------------------------------
# Lambda permissions for API Gateway invocation
#------------------------------------------------------------------------------
resource "aws_lambda_permission" "apigw_greeter" {
  region        = var.region
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_greeter.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_dispatcher" {
  region        = var.region
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_dispatcher.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
