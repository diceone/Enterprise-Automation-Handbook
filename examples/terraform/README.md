# Terraform Examples

Production-ready Terraform configurations for AWS infrastructure.

## Quick Start

### 1. Initialize Terraform

```bash
# Initialize working directory
terraform init

# Validate configuration
terraform validate

# Format configuration
terraform fmt -recursive
```

### 2. Plan Deployment

```bash
# Development environment
terraform plan -var-file="environments/dev.tfvars" -out=tfplan

# Staging environment
terraform plan -var-file="environments/staging.tfvars" -out=tfplan

# Production environment (requires approval)
terraform plan -var-file="environments/prod.tfvars" -out=tfplan
```

### 3. Apply Configuration

```bash
# Apply development
terraform apply tfplan

# Apply production (use saved plan)
terraform apply -lock=true environments/prod.tfplan
```

## File Structure

- `provider.tf` - AWS provider and backend configuration
- `variables.tf` - Input variables with validation
- `outputs.tf` - Output values
- `main.tf` - Resource definitions
- `modules/` - Reusable Terraform modules
- `environments/` - Environment-specific variables

## Key Features

✅ Multi-environment support
✅ S3 backend with state locking
✅ Input validation
✅ Default tags
✅ Security group rules
✅ Load balancer configuration
✅ Encrypted storage

## Environment Configurations

### Development

```bash
# environment: dev
# instances: 1
# instance_type: t3.micro
terraform plan -var-file="environments/dev.tfvars"
```

### Staging

```bash
# environment: staging
# instances: 2
# instance_type: t3.small
terraform plan -var-file="environments/staging.tfvars"
```

### Production

```bash
# environment: prod
# instances: 3
# instance_type: t3.large
terraform plan -var-file="environments/prod.tfvars"
```

## State Management

### Backup State

```bash
terraform state pull > terraform.tfstate.backup
```

### Import Existing Resource

```bash
terraform import aws_instance.web i-1234567890abcdef0
```

### Remove from State

```bash
terraform state rm aws_instance.web
```

## Troubleshooting

### State Lock Issues
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Plan Differences
```bash
# Show detailed diff
terraform plan -out=tfplan
terraform show tfplan
```

### Validation Errors
```bash
# Validate configuration
terraform validate

# Check syntax
terraform fmt -check -recursive
```

## Security Best Practices

- ✅ Enable encryption for S3 backend
- ✅ Use S3 versioning for state files
- ✅ Implement DynamoDB locking
- ✅ Restrict IAM permissions
- ✅ Don't commit .tfstate files
- ✅ Use Terraform Cloud for secrets

## References

- [Terraform Best Practices](../02-terraform-best-practices.md)
- [AWS Terraform Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Official Terraform Documentation](https://www.terraform.io/docs)
