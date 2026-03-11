# Bootstrap - Terraform Backend & GitHub OIDC

This creates the infrastructure needed for secure CI/CD:

1. **S3 Bucket** - Stores Terraform state (encrypted, versioned)
2. **GitHub OIDC Provider** - Allows GitHub Actions to authenticate
3. **IAM Role** - Role that GitHub Actions assumes

Note: State locking uses S3 native locking (`use_lockfile = true`) - no DynamoDB needed (Terraform 1.10+).

## Setup

```bash
cd bootstrap

# Create tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit with your values

# Deploy
terraform init
terraform apply
```

## After Apply

1. **Copy backend config** to `environments/dev/backend.tf`:
   ```hcl
   terraform {
     backend "s3" {
       bucket       = "unleash-assessment-tfstate-ACCOUNT_ID"
       key          = "dev/terraform.tfstate"
       region       = "us-east-1"
       encrypt      = true
       use_lockfile = true
     }
   }
   ```

2. **Add role ARN to GitHub**:
   ```
   Settings → Secrets → Actions → New secret
   Name: AWS_ROLE_ARN
   Value: arn:aws:iam::ACCOUNT_ID:role/unleash-assessment-github-actions
   ```

3. **Migrate state**:
   ```bash
   cd ../environments/dev
   terraform init -migrate-state
   ```

## How OIDC Works

```
GitHub Actions                         AWS
     │                                  │
     │  1. Request OIDC token           │
     │─────────────────────────────────►│
     │                                  │
     │  2. Token with repo info         │
     │◄─────────────────────────────────│
     │                                  │
     │  3. AssumeRoleWithWebIdentity    │
     │─────────────────────────────────►│
     │                                  │
     │  4. Temporary credentials        │
     │◄─────────────────────────────────│
     │                                  │
     │  5. Use credentials for AWS API  │
     │─────────────────────────────────►│
```

No static credentials stored anywhere.
