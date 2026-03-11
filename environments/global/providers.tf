# environments/global/providers.tf
# Global resources are deployed to us-east-1

provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "dev"
      ManagedBy   = "terraform"
      Component   = "global"
    }
  }
}

provider "awscc" {
  region  = "us-east-1"
  profile = var.aws_profile
}
