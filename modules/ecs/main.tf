# modules/ecs/main.tf

#------------------------------------------------------------------------------
# ECS Cluster
#------------------------------------------------------------------------------
module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.3.1"

  region = var.region

  name = "${var.name_prefix}-cluster"

  setting = [
    {
      name  = "containerInsights"
      value = "enhanced"
    }
  ]

  cluster_capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy = {
    FARGATE = {
      weight = 100
      base   = 1
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# CloudWatch Log Group for ECS
#------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ecs" {
  region            = var.region
  name              = "/ecs/${var.name_prefix}-${var.task_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

#------------------------------------------------------------------------------
# ECS Execution Role
#------------------------------------------------------------------------------
module "ecs_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.52.2"

  create_role       = true
  role_name         = "${var.name_prefix}-ecs-exec"
  role_requires_mfa = false

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]

  tags = var.tags
}

#------------------------------------------------------------------------------
# ECS Task Role (SNS publish only)
#------------------------------------------------------------------------------
module "ecs_task_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.52.2"

  create_role       = true
  role_name         = "${var.name_prefix}-ecs-task"
  role_requires_mfa = false

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  inline_policy_statements = [
    {
      sid       = "SNSPublish"
      effect    = "Allow"
      actions   = ["sns:Publish"]
      resources = [var.sns_topic_arn]
    }
  ]

  tags = var.tags
}

#------------------------------------------------------------------------------
# ECS Task Definition
#------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "sns_publisher" {
  region                   = var.region
  family                   = "${var.name_prefix}-${var.task_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = module.ecs_execution_role.iam_role_arn
  task_role_arn            = module.ecs_task_role.iam_role_arn

  container_definitions = jsonencode([
    {
      name       = var.task_name
      image      = var.task_image
      essential  = true
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

  tags = var.tags
}
