# lambda

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_lambda_dispatcher"></a> [lambda\_dispatcher](#module\_lambda\_dispatcher) | terraform-aws-modules/lambda/aws | 8.7.0 |
| <a name="module_lambda_greeter"></a> [lambda\_greeter](#module\_lambda\_greeter) | terraform-aws-modules/lambda/aws | 8.7.0 |

## Resources

| Name | Type |
|------|------|
| [archive_file.dispatcher](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.greeter](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_dispatcher_memory_size"></a> [dispatcher\_memory\_size](#input\_dispatcher\_memory\_size) | Dispatcher Lambda memory size | `number` | `128` | no |
| <a name="input_dispatcher_timeout"></a> [dispatcher\_timeout](#input\_dispatcher\_timeout) | Dispatcher Lambda timeout | `number` | `60` | no |
| <a name="input_dynamodb_table_arn"></a> [dynamodb\_table\_arn](#input\_dynamodb\_table\_arn) | DynamoDB table ARN | `string` | n/a | yes |
| <a name="input_dynamodb_table_name"></a> [dynamodb\_table\_name](#input\_dynamodb\_table\_name) | DynamoDB table name | `string` | n/a | yes |
| <a name="input_ecs_cluster_arn"></a> [ecs\_cluster\_arn](#input\_ecs\_cluster\_arn) | ECS cluster ARN | `string` | n/a | yes |
| <a name="input_ecs_role_arns"></a> [ecs\_role\_arns](#input\_ecs\_role\_arns) | ECS role ARNs for iam:PassRole | `list(string)` | n/a | yes |
| <a name="input_ecs_task_definition_arn"></a> [ecs\_task\_definition\_arn](#input\_ecs\_task\_definition\_arn) | ECS task definition ARN | `string` | n/a | yes |
| <a name="input_email"></a> [email](#input\_email) | Candidate email for SNS payload | `string` | n/a | yes |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | GitHub repo URL for SNS payload | `string` | n/a | yes |
| <a name="input_greeter_memory_size"></a> [greeter\_memory\_size](#input\_greeter\_memory\_size) | Greeter Lambda memory size | `number` | `128` | no |
| <a name="input_greeter_timeout"></a> [greeter\_timeout](#input\_greeter\_timeout) | Greeter Lambda timeout | `number` | `30` | no |
| <a name="input_lambda_source_path"></a> [lambda\_source\_path](#input\_lambda\_source\_path) | Path to lambda source code directory | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention in days | `number` | `7` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | n/a | yes |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | Security group ID for ECS tasks | `string` | n/a | yes |
| <a name="input_sns_topic_arn"></a> [sns\_topic\_arn](#input\_sns\_topic\_arn) | SNS topic ARN | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnet IDs for ECS tasks | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dispatcher_function_arn"></a> [dispatcher\_function\_arn](#output\_dispatcher\_function\_arn) | Dispatcher Lambda function ARN |
| <a name="output_dispatcher_function_name"></a> [dispatcher\_function\_name](#output\_dispatcher\_function\_name) | Dispatcher Lambda function name |
| <a name="output_dispatcher_invoke_arn"></a> [dispatcher\_invoke\_arn](#output\_dispatcher\_invoke\_arn) | Dispatcher Lambda invoke ARN |
| <a name="output_greeter_function_arn"></a> [greeter\_function\_arn](#output\_greeter\_function\_arn) | Greeter Lambda function ARN |
| <a name="output_greeter_function_name"></a> [greeter\_function\_name](#output\_greeter\_function\_name) | Greeter Lambda function name |
| <a name="output_greeter_invoke_arn"></a> [greeter\_invoke\_arn](#output\_greeter\_invoke\_arn) | Greeter Lambda invoke ARN |
<!-- END_TF_DOCS -->
