# modules/lambda/outputs.tf

output "greeter_function_name" {
  description = "Greeter Lambda function name"
  value       = module.lambda_greeter.lambda_function_name
}

output "greeter_function_arn" {
  description = "Greeter Lambda function ARN"
  value       = module.lambda_greeter.lambda_function_arn
}

output "greeter_invoke_arn" {
  description = "Greeter Lambda invoke ARN"
  value       = module.lambda_greeter.lambda_function_invoke_arn
}

output "dispatcher_function_name" {
  description = "Dispatcher Lambda function name"
  value       = module.lambda_dispatcher.lambda_function_name
}

output "dispatcher_function_arn" {
  description = "Dispatcher Lambda function ARN"
  value       = module.lambda_dispatcher.lambda_function_arn
}

output "dispatcher_invoke_arn" {
  description = "Dispatcher Lambda invoke ARN"
  value       = module.lambda_dispatcher.lambda_function_invoke_arn
}
