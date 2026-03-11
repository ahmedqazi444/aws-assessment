# environments/eu-west-1/providers.tf

provider "aws" {
  region  = "eu-west-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "dev"
      ManagedBy   = "terraform"
      Region      = "eu-west-1"
    }
  }
}
