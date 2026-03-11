# modules/compute/vpc.tf

#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  region = var.region
  state  = "available"
}

#------------------------------------------------------------------------------
# VPC using terraform-aws-modules
#------------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  # Region meta-argument (AWS Provider 6.0+)
  region = var.region

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs            = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets = [cidrsubnet(var.vpc_cidr, 8, 0), cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]

  # No NAT Gateway - Fargate tasks will use public IPs
  enable_nat_gateway = false

  # DNS settings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })

  public_subnet_tags = {
    Type = "public"
  }
}

#------------------------------------------------------------------------------
# Security Group for ECS tasks
# Using raw resource instead of module to support region meta-argument
#------------------------------------------------------------------------------
resource "aws_security_group" "ecs" {
  region = var.region

  name        = "${local.name_prefix}-ecs-sg"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = module.vpc.vpc_id

  # Egress rules - HTTPS only for SNS/ECR
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for SNS/ECR"
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-ecs-sg"
  })
}
