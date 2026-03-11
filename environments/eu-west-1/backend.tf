# environments/eu-west-1/backend.tf
# Regional compute state for eu-west-1

terraform {
  backend "s3" {
    bucket       = "unleash-assessment-tfstate-003767002475"
    key          = "eu-west-1/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
