# global

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | ~> 1.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cognito"></a> [cognito](#module\_cognito) | lgallard/cognito-user-pool/aws | 4.0.0 |
| <a name="module_waf_cloudfront"></a> [waf\_cloudfront](#module\_waf\_cloudfront) | aws-ss/wafv2/aws | 4.1.3 |
| <a name="module_waf_cognito"></a> [waf\_cognito](#module\_waf\_cognito) | aws-ss/wafv2/aws | 4.1.3 |

## Resources

| Name | Type |
|------|------|
| [aws_cognito_user.test](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cognito_user) | resource |
| [aws_secretsmanager_secret.cognito_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.cognito_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [random_password.cognito_user](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS CLI profile to use for authentication | `string` | `null` | no |
| <a name="input_email"></a> [email](#input\_email) | Candidate email for Cognito user | `string` | `"ahmed_qazi444@hotmail.com"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name for resource naming | `string` | `"unleash"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cognito_client_id"></a> [cognito\_client\_id](#output\_cognito\_client\_id) | Cognito User Pool Client ID |
| <a name="output_cognito_user_pool_arn"></a> [cognito\_user\_pool\_arn](#output\_cognito\_user\_pool\_arn) | Cognito User Pool ARN for API Gateway authorizers |
| <a name="output_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#output\_cognito\_user\_pool\_id) | Cognito User Pool ID |
| <a name="output_secret_name"></a> [secret\_name](#output\_secret\_name) | Secrets Manager secret name for test user password |
| <a name="output_test_user_email"></a> [test\_user\_email](#output\_test\_user\_email) | Test user email |
| <a name="output_waf_cloudfront_arn"></a> [waf\_cloudfront\_arn](#output\_waf\_cloudfront\_arn) | WAF Web ACL ARN for CloudFront distributions |
<!-- END_TF_DOCS -->
