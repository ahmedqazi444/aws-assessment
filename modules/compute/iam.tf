# modules/compute/iam.tf

#------------------------------------------------------------------------------
# ECS Task Execution Role
# Allows ECS agent to pull images and write logs
#------------------------------------------------------------------------------
module "ecs_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.52.2"

  # Note: IAM is a global service, no region argument needed
  # Region-suffixed names prevent collisions between module instances

  create_role       = true
  role_name         = "${local.name_prefix}-ecs-exec"
  role_requires_mfa = false

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]

  tags = var.common_tags
}

#------------------------------------------------------------------------------
# ECS Task Role
# Permissions available inside the running container (SNS publish only)
#------------------------------------------------------------------------------
module "ecs_task_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.52.2"

  create_role       = true
  role_name         = "${local.name_prefix}-ecs-task"
  role_requires_mfa = false

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  # Inline policy for SNS publish
  inline_policy_statements = [
    {
      sid       = "SNSPublish"
      effect    = "Allow"
      actions   = ["sns:Publish"]
      resources = [length(trimspace(var.sns_topic_arn)) > 0 ? var.sns_topic_arn : "arn:aws:sns:us-east-1:000000000000:dummy-topic"]
    }
  ]

  tags = var.common_tags
}
