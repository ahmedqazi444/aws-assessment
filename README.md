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

### Why I Chose This Over Provider v6 `for_each`

AWS provider v6 introduced [enhanced multi-region support](https://registry.terraform.io/providers/-/aws/latest/docs/guides/enhanced-region-support) that lets you loop over regions with `for_each` on provider blocks, deploying all regions from a single root module in one apply. I deliberately chose the directory-per-region approach instead. Here's my reasoning:

**Advantages of my approach:**

- **Blast radius isolation** — A bad `terraform apply` in `us-east-1` cannot touch `eu-west-1`. Each region has its own state file, so a corrupted state or a broken plan only impacts one region.
- **Independent lifecycle** — I can plan, apply, or destroy one region without touching the others. This is useful for staged rollouts (deploy `us-east-1` first, validate, then `eu-west-1`).
- **Simpler provider config** — One provider per root module, no aliases, no `for_each` on providers. Easy to read and reason about with no dependency on provider v6 features.
- **Parallel CI/CD** — Each region runs as a separate GitHub Actions matrix job in parallel, since they are independent root modules with independent state.
- **Per-region customization** — If I need to give one region different settings (e.g., different `vpc_cidr`, different instance sizes), I just edit that region's variables. No need for complex region-keyed maps.
- **Backward compatible** — Works with any Terraform or OpenTofu version; no dependency on provider v6-specific features.

**Trade-offs I accepted:**

- **Code duplication** — The regional `main.tf` files are nearly identical. Adding a new module means editing every region directory. I mitigate this by keeping the regional files thin (just module calls) and putting all logic in shared modules.
- **Drift risk** — Because files are copied, it's possible to update one region and forget another. CI validation across all components (the matrix strategy in my workflow) catches this.
- **Adding a region is manual** — To add `ap-southeast-1`, I'd copy a directory, update locals/backend/provider, and wire it into the workflow matrix. With `for_each`, it would be one entry in a map.
- **Multiple applies required** — Deploying the full stack requires ordered applies (`global` → regions). The `for_each` approach could handle all regions in a single apply.
- **No atomic multi-region changes** — If I change a module interface (e.g., add a variable to `modules/lambda`), I must update and apply each region separately, risking a window where regions are inconsistent.

**Bottom line:** For two regions with a clear global/regional split, the isolation and simplicity benefits outweigh the duplication cost. If I needed to scale to many more regions with identical stacks, I'd revisit the `for_each` provider approach.

---

## Manual Deployment

### Prerequisites

- Terraform >= 1.10
- AWS CLI v2 configured with credentials
- Python 3 and `pip` (for pre-commit)
- `jq` and `curl` (for test script)

### Install Pre-commit Hooks

```bash
pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
```

This sets up local hooks that run automatically on each commit:
- **Conventional commits** — enforces commit message format
- **terraform_fmt** — auto-formats `.tf` files
- **terraform_docs** — generates module documentation
- **terraform_validate** — validates configuration
- **terraform_providers_lock** — keeps lock files in sync
- **terraform_tflint** — lints Terraform code
- **terraform_trivy** — security scan (HIGH/CRITICAL)

To run all hooks manually against every file:

```bash
pre-commit run --all-files
```

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
| PR to main | CI checks + Terraform plan for all components (posted as PR comments) |
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
| **PRs run plan only (no apply)** | PRs get read-only `terraform plan` posted as comments; apply is blocked |
| **Fork PRs blocked by OIDC** | OIDC trust policy only allows `main` branch to assume the IAM role, so fork PR plans fail safely |
| **Apply requires push to main** | Apply/destroy not triggered by PRs |
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
