# environments/us-east-1/backend.tf
# Regional compute and networking resources for us-east-1
terraform {
  backend "s3" {
    bucket       = "unleash-assessment-tfstate-003767002475"
    key          = "us-east-1/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
