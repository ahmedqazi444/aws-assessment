.PHONY: init plan apply test destroy clean deploy final-submission help bootstrap

# Default target
help:
	@echo "Unleash Live - AWS Assessment"
	@echo ""
	@echo "Usage:"
	@echo "  make init              Initialize Terraform"
	@echo "  make plan              Run terraform plan"
	@echo "  make apply             Apply infrastructure"
	@echo "  make test              Run integration tests"
	@echo "  make deploy            Apply + test (full deployment)"
	@echo "  make destroy           Tear down infrastructure"
	@echo "  make final-submission  Deploy with SNS enabled + test"
	@echo "  make clean             Remove generated files"
	@echo "  make bootstrap         Create S3 backend + OIDC (run once)"

# Directories
TF_DIR := environments/dev
TEST_DIR := test

# Auto-detect AWS profile from terraform.tfvars (for local development)
# CI/CD uses OIDC, so AWS_PROFILE won't be set there
AWS_PROFILE ?= $(shell grep 'aws_profile' $(TF_DIR)/terraform.tfvars 2>/dev/null | sed 's/.*= *"\([^"]*\)".*/\1/')
export AWS_PROFILE


# Initialize Terraform
init:
	@echo "=== Initializing Terraform ==="
	cd $(TF_DIR) && terraform init

# Plan changes
plan:
	@echo "=== Planning Infrastructure ==="
	cd $(TF_DIR) && terraform plan -out=tfplan

# Apply infrastructure
apply:
	@echo "=== Applying Infrastructure ==="
	cd $(TF_DIR) && terraform apply tfplan
	@echo "=== Generating Test Config ==="
	cd $(TF_DIR) && terraform output -json test_config > ../../$(TEST_DIR)/test_config.json
	@echo "Config written to $(TEST_DIR)/test_config.json"

# Run tests
test:
	@echo "=== Running Integration Tests ==="
	@bash $(TEST_DIR)/test_deployment.sh

# Full deployment: apply + test
deploy: apply test
	@echo "=== Deployment Complete ==="

# Destroy infrastructure
destroy:
	@echo "=== Destroying Infrastructure ==="
	cd $(TF_DIR) && terraform destroy -auto-approve

# Final submission with SNS enabled
final-submission:
	@echo "=== Final Submission Mode ==="
	@echo "WARNING: This will send SNS notifications to Unleash Live"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	cd $(TF_DIR) && terraform apply \
		-var="sns_topic_arn=arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic" \
		-var="send_sns=true" \
		-auto-approve
	cd $(TF_DIR) && terraform output -json test_config > ../../$(TEST_DIR)/test_config.json
	@bash $(TEST_DIR)/test_deployment.sh
	@echo ""
	@echo "=== Verify 4 SNS messages received ==="
	@echo "Then run: make destroy"

# Clean generated files
clean:
	rm -f $(TEST_DIR)/test_config.json
	rm -f $(TF_DIR)/tfplan
	rm -f lambda/*.zip

# Bootstrap - create S3 backend + OIDC (run once)
bootstrap:
	@echo "=== Bootstrapping Backend & OIDC ==="
	cd bootstrap && terraform init && terraform apply

