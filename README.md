# AWS Multi-Region Infrastructure

[![Terraform](https://github.com/ahmedqazi444/aws-assessment/actions/workflows/deploy.yml/badge.svg)](https://github.com/ahmedqazi444/aws-assessment/actions/workflows/deploy.yml)

Multi-region serverless infrastructure on AWS using Terraform.

## Architecture

```
                          ┌─────────────────────────────────────────────┐
                          │              Global (us-east-1)             │
                          │  ┌────────────────┐  ┌──────────────────┐   │
                          │  │  Cognito Pool  │  │  WAF Web ACL     │   │
                          │  │  (auth for all │  │  (CloudFront     │   │
                          │  │   regions)     │  │   scope)         │   │
                          │  └──────┬─────────┘  └───────┬──────────┘   │
                          └─────────┼─────────────────────┼─────────────┘
                 ┌──────────────────┼─────────────────────┼──────────────────┐
                 │                  │                     │                  │
    ┌────────────▼──────────────────▼──┐    ┌─────────────▼──────────────────▼─┐
    │        us-east-1 Compute         │    │        eu-west-1 Compute         │
    │  ┌──────────────────────────┐    │    │  ┌──────────────────────────┐    │
    │  │     CloudFront (CDN)     │    │    │  │     CloudFront (CDN)     │    │
    │  │     + WAF association    │    │    │  │     + WAF association    │    │
    │  └────────────┬─────────────┘    │    │  └────────────┬─────────────┘    │
    │  ┌────────────▼─────────────┐    │    │  ┌────────────▼─────────────┐    │
    │  │  API Gateway (HTTP API)  │    │    │  │  API Gateway (HTTP API)  │    │
    │  │  JWT Authorizer→Cognito  │    │    │  │  JWT Authorizer→Cognito  │    │
    │  └──┬──────────────────┬────┘    │    │  └──┬──────────────────┬────┘    │
    │     │                  │         │    │     │                  │         │
    │  ┌──▼────┐       ┌─────▼────┐    │    │  ┌──▼────┐       ┌─────▼────┐    │
    │  │/greet │       │/dispatch │    │    │  │/greet │       │/dispatch │    │
    │  │Lambda │       │  Lambda  │    │    │  │Lambda │       │  Lambda  │    │
    │  └──┬────┘       └─────┬────┘    │    │  └──┬────┘       └─────┬────┘    │
    │     │                  │         │    │     │                  │         │
    │  ┌──▼──────┐  ┌────────▼─────┐   │    │  ┌──▼──────┐  ┌───────▼──────┐   │
    │  │DynamoDB │  │ ECS Fargate  │   │    │  │DynamoDB │  │ ECS Fargate  │   │
    │  │  Table  │  │ (SNS publish)│   │    │  │  Table  │  │ (SNS publish)│   │
    │  └─────────┘  └──────────────┘   │    │  └─────────┘  └──────────────┘   │
    │  VPC: 10.0.0.0/16                │    │  VPC: 10.1.0.0/16                │
    └──────────────────────────────────┘    └──────────────────────────────────┘
```

## Project Structure

```
.
├── environments/
│   ├── global/           # Cognito, WAF, Secrets Manager
│   ├── us-east-1/        # Regional compute stack
│   └── eu-west-1/        # Regional compute stack
├── modules/
│   └── compute/          # Reusable compute module (VPC, Lambda, API GW, ECS, DynamoDB)
├── lambda/
│   ├── greeter/          # /greet endpoint - writes to DynamoDB, publishes to SNS
│   └── dispatcher/       # /dispatch endpoint - triggers ECS Fargate task
├── bootstrap/            # OIDC + S3 backend setup for CI/CD
└── test/
    └── test_deployment.sh
```

## Multi-Region Provider Strategy

This project uses **separate Terraform state files per environment** with **cross-state references** via `terraform_remote_state`:

```
environments/
├── global/          # State: global/terraform.tfstate
│   └── Outputs: cognito_user_pool_arn, cognito_client_id, waf_cloudfront_arn
│
├── us-east-1/       # State: us-east-1/terraform.tfstate
│   └── Reads global outputs via terraform_remote_state
│
└── eu-west-1/       # State: eu-west-1/terraform.tfstate
    └── Reads global outputs via terraform_remote_state
```

**How it works:**

1. **Global environment** (`environments/global/`) deploys shared resources (Cognito, WAF) to `us-east-1` and exports outputs.

2. **Regional environments** (`environments/us-east-1/`, `environments/eu-west-1/`) each have their own provider configured for their specific region:

```hcl
# environments/us-east-1/providers.tf
provider "aws" {
  region = "us-east-1"
}

# environments/eu-west-1/providers.tf
provider "aws" {
  region = "eu-west-1"
}
```

3. **Cross-region dependencies** are resolved via `terraform_remote_state`:

```hcl
# environments/us-east-1/data.tf
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = "your-state-bucket"
    key    = "global/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  cognito_user_pool_arn = data.terraform_remote_state.global.outputs.cognito_user_pool_arn
}
```

4. **Compute module** (`modules/compute/`) is reused by both regional environments, receiving the region as a variable and global resource ARNs from the remote state.

**Benefits:**
- Independent deployment of each region
- Isolated blast radius per region
- Clear separation between global and regional resources
- Parallel regional deployments possible

---

## Manual Deployment

### Prerequisites

- Terraform >= 1.10
- AWS CLI v2 configured with credentials
- `jq` and `curl` (for test script)

### Step 1: Bootstrap (First Time Only)

Set up the S3 backend and OIDC role for GitHub Actions:

```bash
cd bootstrap
terraform init
terraform apply -var="github_org=YOUR_ORG" -var="github_repo=YOUR_REPO"
```

This creates:
- S3 bucket for Terraform state
- IAM OIDC provider for GitHub Actions
- IAM role for CI/CD

### Step 2: Deploy Global Resources

Global resources (Cognito, WAF) must be deployed first:

```bash
cd environments/global
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Outputs:
- `cognito_user_pool_id` - User pool ID for authentication
- `cognito_client_id` - App client ID
- `secret_name` - Secrets Manager secret with test user password
- `waf_cloudfront_arn` - WAF Web ACL ARN for CloudFront

### Step 3: Deploy Regional Stacks

Deploy compute resources to each region. Order doesn't matter; they can run in parallel:

**US East (us-east-1):**
```bash
cd environments/us-east-1
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**EU West (eu-west-1):**
```bash
cd environments/eu-west-1
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Each regional stack outputs:
- `api_gateway_url` - API Gateway endpoint
- `cloudfront_url` - CloudFront distribution URL

### Step 4: Verify Deployment

Check outputs from all environments:

```bash
# Global outputs
cd environments/global && terraform output

# Regional outputs
cd environments/us-east-1 && terraform output
cd environments/eu-west-1 && terraform output
```

---

## Running the Test Script

The test script validates the entire deployment by authenticating and calling both endpoints in both regions.

### Run the Tests

```bash
bash test/test_deployment.sh
```

### What the Test Script Does

1. **Retrieves Terraform outputs** from all three environments (global, us-east-1, eu-west-1)
2. **Fetches test user password** from AWS Secrets Manager
3. **Authenticates with Cognito** using `USER_PASSWORD_AUTH` flow to get a JWT token
4. **Calls `/greet` endpoint** concurrently on both regions via CloudFront
5. **Calls `/dispatch` endpoint** concurrently on both regions via CloudFront
6. **Validates responses:**
   - HTTP 200 status code
   - Response `region` field matches expected region
   - Measures and displays latency in milliseconds

### Expected Output

```
============================================
  Unleash Live — Deployment Test
============================================

[1/4] Retrieving password from Secrets Manager...
[2/4] Authenticating with Cognito...
✓ JWT token retrieved

[3/4] Calling /greet concurrently...
✓ us-east-1 /greet — 234ms — region: us-east-1
✓ eu-west-1 /greet — 312ms — region: eu-west-1

[4/4] Calling /dispatch concurrently...
✓ us-east-1 /dispatch — 1823ms — region: us-east-1
✓ eu-west-1 /dispatch — 2104ms — region: eu-west-1

============================================
  All tests passed!
============================================
```

---

## CI/CD Workflow

The GitHub Actions workflow (`.github/workflows/deploy.yml`) automates the deployment:

| Trigger | Behavior |
|---------|----------|
| PR to main | CI checks only (no AWS credentials) |
| Push to main | Plan → Apply global → Plan regions → Apply regions |
| workflow_dispatch: plan | Plan selected component |
| workflow_dispatch: apply | Apply selected component |
| workflow_dispatch: destroy | Destroy (regions first, then global) |

**Component options:** `all`, `global`, `us-east-1`, `eu-west-1`

### Required GitHub Configuration

**Secrets** (Settings → Secrets → Actions):

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN` | IAM role ARN from bootstrap output |
| `SNS_TOPIC_ARN` | SNS topic for candidate verification |

**Environments** (Settings → Environments):

| Environment | Purpose |
|-------------|---------|
| `global` | Approval gate for global resources |
| `us-east-1` | Approval gate for US East region |
| `eu-west-1` | Approval gate for EU West region |

---

## Public Repository Security

This workflow is designed for public repositories:

| Security Measure | Implementation |
|-----------------|----------------|
| **PRs run CI checks only** | No AWS credentials exposed to fork PRs |
| **Plan/Apply require push to main** | Not triggered by PRs |
| **OIDC trust policy restricted** | Only `main` branch and protected environments can assume IAM role |
| **Environment protection** | Manual approval required for apply/destroy |
| **No long-lived credentials** | OIDC federation - no AWS keys stored in GitHub |

---

## Infrastructure Security

- **Cognito JWT Auth** - All API routes require valid JWT token
- **WAF Protection** - Rate limiting (500 req/5min/IP) + AWS Managed Common Rules + Known Bad Inputs
- **Least-Privilege IAM** - Each Lambda and ECS task has minimal required permissions
- **Secrets Manager** - Test user password stored securely, never in code/state
- **VPC Flow Logs** - Network traffic logging enabled
- **DynamoDB Encryption** - Server-side encryption at rest
- **CloudFront HTTPS** - Redirect-to-HTTPS viewer protocol policy
- **Security Groups** - ECS tasks have egress-only rules (HTTPS/443)

---

## Cleanup

### Via GitHub Actions (Recommended)

1. Go to Actions → Terraform → Run workflow
2. Select `action: destroy`, `component: all`
3. Approve the `destroy` environment

### Manual Cleanup

**Order matters** - destroy regions before global:

```bash
# Destroy regional stacks first (can be parallel)
cd environments/us-east-1 && terraform destroy -auto-approve
cd environments/eu-west-1 && terraform destroy -auto-approve

# Then destroy global resources
cd environments/global && terraform destroy -auto-approve
```
