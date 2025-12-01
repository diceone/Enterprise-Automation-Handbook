# Terraform Best Practices

A comprehensive guide for DevOps Engineers on implementing Terraform infrastructure as code effectively and reliably.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Core Concepts](#core-concepts)
3. [Configuration Management](#configuration-management)
4. [Modularity and Reusability](#modularity-and-reusability)
5. [State Management](#state-management)
6. [Variables and Secrets](#variables-and-secrets)
7. [Error Handling and Safety](#error-handling-and-safety)
8. [Testing and Validation](#testing-and-validation)
9. [Performance Optimization](#performance-optimization)
10. [Documentation and Maintenance](#documentation-and-maintenance)
11. [Security Best Practices](#security-best-practices)

---

## Project Structure

### Recommended Directory Layout

```
terraform-project/
├── README.md                          # Project overview
├── terraform.tf                       # Terraform version and required providers
├── versions.tf                        # Provider version constraints
├── provider.tf                        # Provider configuration
├── variables.tf                       # Input variables
├── outputs.tf                         # Output definitions
├── main.tf                            # Main resource definitions
├── locals.tf                          # Local values
├── data.tf                            # Data sources
│
├── environments/
│   ├── production/
│   │   ├── terraform.tfvars          # Production variables
│   │   ├── backend.tf                # Backend configuration
│   │   └── override.tf               # Production overrides
│   │
│   ├── staging/
│   │   ├── terraform.tfvars
│   │   ├── backend.tf
│   │   └── override.tf
│   │
│   └── development/
│       ├── terraform.tfvars
│       ├── backend.tf
│       └── override.tf
│
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── README.md
│   │   └── versions.tf
│   │
│   ├── compute/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── README.md
│   │   └── versions.tf
│   │
│   └── database/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── README.md
│       └── versions.tf
│
├── scripts/
│   ├── init.sh                       # Initialize Terraform
│   ├── plan.sh                       # Generate plan
│   ├── apply.sh                      # Apply changes
│   └── validate.sh                   # Validate configuration
│
├── tests/
│   ├── unit/
│   └── integration/
│
├── .terraform.lock.hcl               # Provider version lock
├── .gitignore
└── .terraformignore

```

### Key Principles

- **Modularity**: Each module should manage a single logical resource group
- **Clarity**: Separate concerns (VPC, Compute, Database)
- **Reusability**: Modules should be shareable across projects
- **Scalability**: Support multiple environments without duplication
- **Environment Isolation**: Use separate state files per environment
- **Version Control**: Lock provider and module versions

---

## Core Concepts

### Terraform Workflow

```
Write → Plan → Review → Apply → Destroy
```

1. **Write**: Define infrastructure in HCL
2. **Plan**: Preview changes (terraform plan)
3. **Review**: Validate changes before applying
4. **Apply**: Execute infrastructure changes
5. **Destroy**: Clean up resources when no longer needed

### HCL Fundamentals

#### Blocks

```hcl
# Resource block
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  tags = {
    Name = "web-server"
  }
}

# Module block
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr = var.vpc_cidr
  environment = var.environment
}

# Variable block
variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

# Output block
output "instance_id" {
  value       = aws_instance.web.id
  description = "ID of the EC2 instance"
}

# Data block (read-only)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}
```

#### Expressions and Functions

```hcl
# String interpolation
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  tags = {
    Name = "${var.project_name}-web-${count.index + 1}"
  }
}

# Conditional expressions
resource "aws_security_group" "allow_ssh" {
  name = var.enable_ssh ? "allow-ssh" : "deny-ssh"
}

# Loops - count
resource "aws_instance" "web" {
  count         = var.instance_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  tags = {
    Name = "web-${count.index + 1}"
  }
}

# Loops - for_each
resource "aws_security_group_rule" "allow" {
  for_each = toset(var.allowed_ports)
  
  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
}

# Functions
locals {
  instance_name = format("%s-instance-%d", var.project_name, var.environment_id)
  all_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}
```

---

## Configuration Management

### Provider Configuration

#### Single Provider

```hcl
# provider.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  }
}
```

#### Multiple Providers (Multi-Region/Multi-Cloud)

```hcl
# provider.tf
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

# Use provider alias
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${var.project_name}-primary"
}

resource "aws_s3_bucket" "secondary" {
  provider = aws.secondary
  bucket   = "${var.project_name}-secondary"
}
```

### Backend Configuration

#### Remote State (Recommended)

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

#### Backend with Partial Configuration

```bash
# Initialize with backend configuration from command line
terraform init -backend-config="bucket=my-state" \
               -backend-config="key=prod/terraform.tfstate" \
               -backend-config="region=us-east-1"
```

#### Local State (Development Only)

```hcl
# terraform.tf
terraform {
  # No backend block - uses local state
}
```

### Environment-Specific Configuration

#### Using Workspaces

```bash
# Create and switch workspaces
terraform workspace new production
terraform workspace new staging
terraform workspace select production

# Current workspace: ${terraform.workspace}
resource "aws_s3_bucket" "data" {
  bucket = "data-${terraform.workspace}"
}
```

#### Using Environment Variables

```bash
# Set variables via environment
export TF_VAR_environment="production"
export TF_VAR_instance_count="5"

terraform plan
```

#### Using .tfvars Files

```hcl
# terraform.tfvars (never commit to git)
aws_region         = "us-east-1"
environment        = "production"
instance_count     = 5
instance_type      = "t3.large"

# environments/production/terraform.tfvars
environment        = "production"
instance_type      = "t3.large"
enable_monitoring  = true

# Use specific tfvars file
terraform plan -var-file="environments/production/terraform.tfvars"
```

---

## Modularity and Reusability

### Module Structure

```
modules/vpc/
├── main.tf                    # Resource definitions
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── versions.tf                # Provider requirements
├── README.md                  # Documentation
└── examples/
    └── complete/
        ├── main.tf
        ├── variables.tf
        └── terraform.tfvars
```

### Creating Reusable Modules

#### VPC Module Example

```hcl
# modules/vpc/variables.tf
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Enable NAT Gateway"
  default     = false
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones"
  default     = ["us-east-1a", "us-east-1b"]
}

# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.environment}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.environment}-public-${count.index + 1}"
  }
}

# modules/vpc/outputs.tf
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Public subnet IDs"
}

output "vpc_cidr" {
  value       = aws_vpc.main.cidr_block
  description = "VPC CIDR block"
}
```

#### Using the Module

```hcl
# main.tf
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr              = var.vpc_cidr
  environment           = var.environment
  enable_nat_gateway    = var.enable_nat_gateway
  availability_zones    = var.availability_zones
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = module.vpc.subnet_ids[0]
  
  tags = {
    Name = "${var.environment}-web"
  }
}
```

### Module Composition

```hcl
# main.tf - Compose multiple modules
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr    = var.vpc_cidr
  environment = var.environment
}

module "compute" {
  source = "./modules/compute"
  
  environment    = var.environment
  subnet_ids     = module.vpc.subnet_ids
  instance_count = var.instance_count
  
  depends_on = [module.vpc]
}

module "database" {
  source = "./modules/database"
  
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  
  depends_on = [module.vpc]
}
```

---

## State Management

### State File Best Practices

#### Protect Your State

```hcl
# backend.tf - Enable encryption and locking
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true              # Enable encryption
    dynamodb_table = "terraform-locks" # Enable state locking
  }
}
```

#### Lock Table Setup

```hcl
# Create DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  tags = {
    Name = "terraform-locks"
  }
}
```

### State Inspection and Manipulation

```bash
# View state
terraform state list
terraform state show aws_instance.web

# Import existing resource
terraform import aws_instance.web i-1234567890abcdef0

# Remove resource from state (doesn't destroy)
terraform state rm aws_instance.web

# Move resource within state
terraform state mv aws_instance.web aws_instance.app

# Backup state
terraform state pull > terraform.tfstate.backup
```

### Remote State with Modules

```hcl
# Use outputs from one stack as inputs to another
data "terraform_remote_state" "vpc" {
  backend = "s3"
  
  config = {
    bucket = "terraform-state"
    key    = "vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_instance" "web" {
  subnet_id = data.terraform_remote_state.vpc.outputs.subnet_id
}
```

---

## Variables and Secrets

### Variable Types and Validation

```hcl
# Primitive types
variable "instance_count" {
  type = number
  default = 2
}

variable "enable_monitoring" {
  type = bool
  default = true
}

variable "instance_type" {
  type = string
  default = "t3.micro"
}

# Complex types
variable "tags" {
  type = map(string)
  default = {
    Project = "MyApp"
  }
}

variable "subnet_cidrs" {
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_config" {
  type = object({
    type  = string
    count = number
    tags  = map(string)
  })
  
  default = {
    type  = "t3.micro"
    count = 2
    tags  = { Name = "web" }
  }
}
```

### Input Validation

```hcl
variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  
  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
    error_message = "Instance type must be t3.micro, t3.small, or t3.medium."
  }
}

variable "environment" {
  type        = string
  description = "Environment name"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}
```

### Secrets Management

#### Option 1: AWS Secrets Manager

```hcl
# Get secret from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}

resource "aws_db_instance" "postgres" {
  allocated_storage = 20
  engine            = "postgres"
  engine_version    = "13.7"
  instance_class    = "db.t3.micro"
  
  username = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["username"]
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}
```

#### Option 2: HashiCorp Vault

```hcl
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }
}

provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
}

data "vault_generic_secret" "db_credentials" {
  path = "secret/prod/database"
}

resource "aws_db_instance" "postgres" {
  username = data.vault_generic_secret.db_credentials.data["username"]
  password = data.vault_generic_secret.db_credentials.data["password"]
}
```

#### Option 3: Environment Variables (Development Only)

```bash
export TF_VAR_db_password="supersecret"
terraform apply
```

Never commit `.tfvars` files with secrets to version control. Use `.gitignore`:

```
# .gitignore
*.tfvars
!example.tfvars
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
```

---

## Error Handling and Safety

### Pre-Apply Validation

```hcl
# locals.tf - Validation logic
locals {
  # Validate backend configuration
  backend_valid = (
    var.backend_type == "s3" && var.s3_bucket != ""
  ) || (
    var.backend_type == "local"
  )
  
  # Throw error if invalid
  validate_backend = regex("^valid$", local.backend_valid ? "valid" : "invalid")
}

# main.tf - Conditional resource creation
resource "null_resource" "validation" {
  count = local.backend_valid ? 0 : 1
  
  provisioner "local-exec" {
    command = "echo 'Invalid backend configuration' && exit 1"
  }
}
```

### Prevent Accidental Destruction

```hcl
# Lifecycle rule - prevent destruction
resource "aws_db_instance" "production" {
  allocated_storage   = 20
  identifier          = "prod-db"
  engine              = "mysql"
  instance_class      = "db.t3.small"
  username            = "admin"
  password            = var.db_password
  
  skip_final_snapshot = false
  final_snapshot_identifier = "prod-db-backup-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  lifecycle {
    prevent_destroy = true
  }
}

# Prevent destruction with variable flag
resource "aws_s3_bucket" "critical_data" {
  bucket = "critical-data"
  
  lifecycle {
    prevent_destroy = var.environment == "production"
  }
}
```

### Safe Destroy Workflow

```bash
# 1. Plan destroy to see what will be deleted
terraform plan -destroy

# 2. Review the plan carefully
# 3. Apply destroy only after confirmation
terraform destroy -auto-approve=false
```

### Backup Before Apply

```bash
# Backup current state
terraform state pull > terraform.tfstate.backup

# Safe apply
terraform apply
```

---

## Testing and Validation

### Terraform Validation

```bash
# Check syntax and internal consistency
terraform fmt -check -recursive
terraform validate

# Lint with tflint
tflint
```

### Plan and Review

```bash
# Generate and save plan
terraform plan -out=tfplan

# Review plan file
terraform show tfplan

# Apply saved plan (prevents drift)
terraform apply tfplan
```

### Testing Frameworks

#### Terratest (Go)

```go
package test

import (
  "testing"
  "terraform-modules/test/fixtures"
  
  "github.com/gruntwork-io/terratest/modules/terraform"
)

func TestVPCModule(t *testing.T) {
  terraformOptions := &terraform.Options{
    TerraformDir: "../fixtures/vpc",
  }
  
  defer terraform.Destroy(t, terraformOptions)
  
  terraform.InitAndApply(t, terraformOptions)
  
  vpcId := terraform.Output(t, terraformOptions, "vpc_id")
  
  if vpcId == "" {
    t.Fatal("VPC ID is empty")
  }
}
```

#### Terraform Cloud Testing

```hcl
# terraform.tf - Enable cloud testing
terraform {
  cloud {
    organization = "my-org"
    
    workspaces {
      name = "test-workspace"
    }
  }
}
```

---

## Performance Optimization

### Parallel Execution

```bash
# Control parallelism (default is 10)
terraform apply -parallelism=20
```

### Reduce Provider Overhead

```hcl
# Use data sources instead of resources for read-only
data "aws_ami" "ubuntu" {
  most_recent = true
  
  filter {
    name   = "name"
    values = ["ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Avoid unnecessary AWS API calls
data "aws_availability_zones" "available" {
  state = "available"
}
```

### Lazy Evaluation with Locals

```hcl
locals {
  # Only computed when used
  expensive_calculation = jsonencode({
    for az in data.aws_availability_zones.available.names :
    az => {
      name = az
      tier = "standard"
    }
  })
}
```

### Optimize Module Dependencies

```hcl
# Good - explicit dependencies only where needed
module "vpc" {
  source = "./modules/vpc"
}

module "compute" {
  source     = "./modules/compute"
  subnet_ids = module.vpc.subnet_ids
}

module "logging" {
  source = "./modules/logging"
  # Can run in parallel with compute
}
```

---

## Documentation and Maintenance

### Auto-Generated Documentation

```bash
# Generate documentation from HCL comments
terraform-docs markdown table --output-file README.md .
```

### README Template for Modules

```markdown
# VPC Module

Provisions a production-ready VPC with public and private subnets.

## Usage

\`\`\`hcl
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr   = "10.0.0.0/16"
  environment = "production"
}
\`\`\`

## Inputs

| Name | Type | Default | Required |
|------|------|---------|----------|
| vpc_cidr | string | - | yes |
| environment | string | - | yes |
| enable_nat | bool | false | no |

## Outputs

| Name | Value |
|------|-------|
| vpc_id | VPC identifier |
| subnet_ids | List of subnet IDs |

## Troubleshooting

### Issue: Subnet creation fails
**Solution**: Verify CIDR block doesn't exceed /16

```

### Versioning

```hcl
# versions.tf - Pin provider and module versions
terraform {
  required_version = ">= 1.0, < 2.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allow patch updates
    }
  }
}

# Module versioning
module "vpc" {
  source = "git::https://git.company.com/terraform-modules/vpc.git?ref=v2.1.0"
}
```

---

## Security Best Practices

### 1. Principle of Least Privilege

```hcl
# Create minimal IAM role
resource "aws_iam_role" "ec2_role" {
  name = "ec2-minimal-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach specific policy, not AdministratorAccess
resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2-policy"
  role = aws_iam_role.ec2_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.app.arn}",
          "${aws_s3_bucket.app.arn}/*"
        ]
      }
    ]
  })
}
```

### 2. Encryption

```hcl
# Encrypt S3 bucket
resource "aws_s3_bucket" "data" {
  bucket = "app-data"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Encrypt EBS volume
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }
}
```

### 3. Secure Communication

```hcl
# Use security groups restrictively
resource "aws_security_group" "web" {
  name = "web-sg"
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTPS only
  }
  
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]  # Only from app tier
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### 4. Audit and Logging

```hcl
# Enable CloudTrail
resource "aws_cloudtrail" "audit" {
  name           = "terraform-audit"
  s3_bucket_name = aws_s3_bucket.audit_logs.id
  
  is_multi_region_trail = true
  include_global_events = true
  enable_log_file_validation = true
  
  depends_on = [aws_s3_bucket_policy.audit_logs]
}

# Enable VPC Flow Logs
resource "aws_flow_log" "vpc_logs" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}
```

### 5. Secrets Never in Code

```hcl
# DON'T: Hardcode secrets
resource "aws_db_instance" "bad" {
  password = "hardcoded_password"  # NEVER!
}

# DO: Use secrets manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}

resource "aws_db_instance" "good" {
  password = jsondecode(
    data.aws_secretsmanager_secret_version.db_password.secret_string
  )["password"]
}

# DO: Use variables (set via environment)
variable "db_password" {
  type      = string
  sensitive = true  # Hide from output
}

resource "aws_db_instance" "better" {
  password = var.db_password
}
```

---

## Common Patterns and Templates

### Multi-Environment Setup

```hcl
# main.tf - Use workspace to select environment
locals {
  env_config = {
    development = {
      instance_type = "t3.micro"
      instance_count = 1
      enable_monitoring = false
    }
    staging = {
      instance_type = "t3.small"
      instance_count = 2
      enable_monitoring = true
    }
    production = {
      instance_type = "t3.large"
      instance_count = 5
      enable_monitoring = true
    }
  }
  
  current = local.env_config[terraform.workspace]
}

resource "aws_instance" "web" {
  count         = local.current.instance_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = local.current.instance_type
}
```

### Conditional Resources

```hcl
# Create resources conditionally
variable "enable_backup" {
  type    = bool
  default = true
}

resource "aws_backup_vault" "main" {
  count = var.enable_backup ? 1 : 0
  name  = "backup-vault"
}

resource "aws_backup_plan" "main" {
  count = var.enable_backup ? 1 : 0
  name  = "backup-plan"
}
```

### Dynamic Blocks

```hcl
# Use dynamic blocks to reduce repetition
resource "aws_security_group" "web" {
  name = "web-sg"
  
  dynamic "ingress" {
    for_each = var.allowed_ports
    
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
```

---

## Troubleshooting Tips

| Issue | Solution | Example |
|-------|----------|---------|
| State lock stuck | Remove lock in DynamoDB | `aws dynamodb delete-item --table-name terraform-locks --key '{"LockID":{"S":"..."}}' ` |
| Provider version mismatch | Update lock file | `rm .terraform.lock.hcl && terraform init` |
| Resource already exists | Import existing resource | `terraform import aws_instance.web i-1234567890` |
| Drift detected | Re-apply configuration | `terraform apply` |
| Module not found | Initialize modules | `terraform init -upgrade` |
| State corruption | Restore from backup | `terraform state push backup.tfstate` |
| Circular dependency | Reorder modules | Use `depends_on` explicitly |
| Destroy fails | Check resource dependencies | `terraform destroy -auto-approve=false` |
| Output not available | Ensure apply completed | `terraform output` after apply |
| Sensitive output visible | Mark variable as sensitive | `sensitive = true` |

---

## References and Resources

- [Official Terraform Documentation](https://www.terraform.io/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Module Registry](https://registry.terraform.io/)
- [Terraform Best Practices by HashiCorp](https://www.terraform.io/cloud-docs/state/best-practices)
- [tflint - Terraform Linter](https://github.com/terraform-linters/tflint)
- [Terratest - Testing Terraform](https://terratest.gruntwork.io/)

---

**Version**: 1.0  
**Author**: Michael Vogeler  
**Last Updated**: December 1, 2025  
**Maintained By**: DevOps Team
