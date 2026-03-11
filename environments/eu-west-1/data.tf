# environments/eu-west-1/data.tf
# Read outputs from global state

data "terraform_remote_state" "global" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "global/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  cognito_user_pool_arn = data.terraform_remote_state.global.outputs.cognito_user_pool_arn
  cognito_client_id     = data.terraform_remote_state.global.outputs.cognito_client_id
  waf_cloudfront_arn    = data.terraform_remote_state.global.outputs.waf_cloudfront_arn
}
