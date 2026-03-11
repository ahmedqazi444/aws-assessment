# modules/compute/locals.tf
# Computed local values for the compute module

locals {
  # Resource naming pattern
  name_prefix = "${var.project_name}-${var.region}"

  # Lambda defaults (can be overridden by variable)
  lambda_defaults = {
    runtime      = "python3.12"
    architecture = "arm64"
  }

  # CloudWatch defaults
  cloudwatch_defaults = {
    log_retention_days = 7
  }

  # Greeter Lambda configuration (merged with any overrides from variable)
  greeter_config = merge(local.lambda_defaults, {
    timeout     = try(var.lambda_config.greeter.timeout, 30)
    memory_size = try(var.lambda_config.greeter.memory_size, 128)
  })

  # Dispatcher Lambda configuration (merged with any overrides from variable)
  dispatcher_config = merge(local.lambda_defaults, {
    timeout     = try(var.lambda_config.dispatcher.timeout, 60)
    memory_size = try(var.lambda_config.dispatcher.memory_size, 128)
  })

  # API Gateway domain (extracted from stage invoke URL for CloudFront origin)
  # REST API stage URL format: https://{api-id}.execute-api.{region}.amazonaws.com/{stage}
  api_gateway_invoke_url  = aws_api_gateway_stage.prod.invoke_url
  api_gateway_domain      = "${aws_api_gateway_rest_api.main.id}.execute-api.${var.region}.amazonaws.com"
  api_gateway_origin_path = "/${aws_api_gateway_stage.prod.stage_name}"
}
