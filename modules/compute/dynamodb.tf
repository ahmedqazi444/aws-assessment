# modules/compute/dynamodb.tf

#------------------------------------------------------------------------------
# DynamoDB Table for Greeting Logs
#------------------------------------------------------------------------------
module "dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "5.5.0"

  # Region meta-argument (AWS Provider 6.0+)
  region = var.region

  name     = "${local.name_prefix}-GreetingLogs"
  hash_key = "id"

  billing_mode = "PAY_PER_REQUEST"

  attributes = [
    {
      name = "id"
      type = "S"
    }
  ]

  server_side_encryption_enabled = true

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-GreetingLogs"
  })
}
