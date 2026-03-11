# modules/compute/ecs.tf

#------------------------------------------------------------------------------
# ECS Cluster using terraform-aws-modules
#------------------------------------------------------------------------------
module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.3.1"

  # Region meta-argument (AWS Provider 6.0+)
  region = var.region

  name = "${local.name_prefix}-cluster"

  # Container Insights - enhanced mode
  setting = [
    {
      name  = "containerInsights"
      value = "enhanced"
    }
  ]

  # Fargate capacity provider
  cluster_capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy = {
    FARGATE = {
      weight = 100
      base   = 1
    }
  }

  tags = var.common_tags
}

#------------------------------------------------------------------------------
# CloudWatch Log Group for ECS
#------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ecs" {
  region            = var.region
  name              = "/ecs/${local.name_prefix}-${var.ecs_task_config.name}"
  retention_in_days = local.cloudwatch_defaults.log_retention_days

  tags = var.common_tags
}

#------------------------------------------------------------------------------
# ECS Task Definition
# Note: Using raw resource instead of service module because this is a
# run-once task triggered by Lambda, not a long-running service
#------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "sns_publisher" {
  region                   = var.region
  family                   = "${local.name_prefix}-${var.ecs_task_config.name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.ecs_task_config.cpu)
  memory                   = tostring(var.ecs_task_config.memory)
  execution_role_arn       = module.ecs_execution_role.iam_role_arn
  task_role_arn            = module.ecs_task_role.iam_role_arn

  container_definitions = jsonencode([
    {
      name      = var.ecs_task_config.name
      image     = var.ecs_task_config.image
      essential = true
      # Override entrypoint since amazon/aws-cli uses 'aws' as entrypoint
      entryPoint = ["/bin/sh", "-c"]
      command = [
        "aws sns publish --topic-arn ${var.sns_topic_arn} --region us-east-1 --message '{\"email\":\"${var.email}\",\"source\":\"ECS\",\"region\":\"${var.region}\",\"repo\":\"${var.github_repo}\"}' --subject 'Candidate Verification - ECS - ${var.region}' && echo 'SNS published'"
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = var.common_tags
}
