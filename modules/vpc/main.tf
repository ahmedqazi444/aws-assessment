# modules/vpc/main.tf

data "aws_availability_zones" "available" {
  region = var.region
  state  = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  region = var.region

  name = "${var.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs            = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets = [cidrsubnet(var.vpc_cidr, 8, 0), cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]

  enable_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = var.tags

  public_subnet_tags = {
    Type = "public"
  }
}

resource "aws_security_group" "ecs" {
  region = var.region

  name        = "${var.name_prefix}-ecs-sg"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for SNS/ECR"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-sg"
  })
}
