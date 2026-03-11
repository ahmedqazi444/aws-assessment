# environments/global/backend.tf
# Global resources state (Cognito, WAF, Secrets Manager)

terraform {
  backend "s3" {
    bucket       = "unleash-assessment-tfstate-003767002475"
    key          = "global/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
