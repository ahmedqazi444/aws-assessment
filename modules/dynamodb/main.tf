# modules/dynamodb/main.tf

module "dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "5.5.0"

  region = var.region

  name     = "${var.name_prefix}-GreetingLogs"
  hash_key = "id"

  billing_mode = "PAY_PER_REQUEST"

  attributes = [
    {
      name = "id"
      type = "S"
    }
  ]

  server_side_encryption_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-GreetingLogs"
  })
}
