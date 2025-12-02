# Local DevOps Development Environment Setup

Comprehensive guide to setting up and maintaining efficient local development environments for DevOps engineers working with Ansible, Terraform, Kubernetes, and CI/CD pipelines.

## Table of Contents

1. [Environment Overview](#environment-overview)
2. [Core DevOps Tools](#core-devops-tools)
3. [Infrastructure as Code Tools](#infrastructure-as-code-tools)
4. [Container & Orchestration](#container--orchestration)
5. [Version Control & Collaboration](#version-control--collaboration)
6. [Local Database & Services](#local-database--services)
7. [Monitoring & Debugging](#monitoring--debugging)
8. [IDE & Editor Setup](#ide--editor-setup)
9. [Environment Automation](#environment-automation)
10. [Performance Optimization](#performance-optimization)
11. [Security Considerations](#security-considerations)
12. [Troubleshooting](#troubleshooting)

## Environment Overview

### Recommended Local DevOps Environment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│         Local DevOps Development Environment                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Version Control           IaC Development                  │
│  ├─ Git/GitHub Desktop     ├─ Terraform                     │
│  ├─ SSH Keys               ├─ Ansible                       │
│  └─ GPG Signing            ├─ HCL/YAML Linting              │
│                            └─ Validation Tools              │
│                                                             │
│  Local Kubernetes          CI/CD Simulation                 │
│  ├─ Docker Desktop         ├─ LocalStack                    │
│  ├─ Kind/Minikube          ├─ GitLab Runner                 │
│  ├─ kubectl CLI            ├─ Testcontainers                │
│  └─ Helm                   └─ Mock Services                 │
│                                                             │
│  Databases & Services      Monitoring & Logging             │
│  ├─ PostgreSQL             ├─ Prometheus                    │
│  ├─ Redis                  ├─ Grafana                       │
│  ├─ MongoDB                ├─ Loki                          │
│  └─ Docker Compose         └─ Jaeger                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Hardware Recommendations

```yaml
minimum_requirements:
  cpu: "4 cores (Intel i5/AMD Ryzen 5 or equivalent)"
  ram: "8 GB"
  storage: "250 GB SSD (minimum)"
  notes: "Can work but tight for all tools"

recommended:
  cpu: "8+ cores (Intel i7/i9 or AMD Ryzen 7/9)"
  ram: "16-32 GB"
  storage: "500+ GB SSD"
  notes: "Comfortable for multi-container development"

optimal_for_serious_devops:
  cpu: "12+ cores"
  ram: "32-64 GB"
  storage: "1TB+ SSD"
  notes: "Full-featured local simulation environment"
```

## Core DevOps Tools

### Essential Tools (MUST HAVE)

```yaml
essential_tools:
  
  git:
    description: "Version control system"
    install: "brew install git"
    verification: "git --version"
    config: |
      git config --global user.name "Your Name"
      git config --global user.email "your.email@company.com"
      git config --global core.editor "vim"
    notes: "Foundation for all collaboration"
    
  curl:
    description: "HTTP client for testing APIs"
    install: "brew install curl"
    verification: "curl --version"
    notes: "Already on macOS, but update recommended"
    
  jq:
    description: "JSON query and manipulation"
    install: "brew install jq"
    verification: "jq --version"
    usage: "curl https://api.example.com | jq '.data[]'"
    
  make:
    description: "Build automation"
    install: "Built-in on macOS"
    verification: "make --version"
    usage: "Automate common development tasks"
    
  openssh:
    description: "SSH client and key management"
    install: "Built-in on macOS"
    verification: "ssh -V"
    setup: |
      ssh-keygen -t ed25519 -C "your.email@company.com"
      eval "$(ssh-agent -s)"
      ssh-add ~/.ssh/id_ed25519
```

### Strongly Recommended Tools

```yaml
strongly_recommended:
  
  docker_desktop:
    description: "Container runtime and local Kubernetes"
    install: "Download from https://www.docker.com/products/docker-desktop"
    verification: "docker --version && docker run hello-world"
    config: |
      # Allocate resources
      - Memory: 8-12 GB
      - CPUs: 4-6
      - Disk: 50+ GB
    why_essential: "Base for all containerized development"
    
  kubectl:
    description: "Kubernetes command-line tool"
    install: "brew install kubectl"
    verification: "kubectl version --client"
    enable_in_docker: |
      Docker Desktop > Preferences > Kubernetes > Enable Kubernetes
    notes: "Required for K8s development"
    
  helm:
    description: "Kubernetes package manager"
    install: "brew install helm"
    verification: "helm version"
    setup: |
      helm repo add stable https://charts.helm.sh/stable
      helm repo update
    
  aws_cli:
    description: "AWS command-line interface"
    install: "brew install awscli"
    verification: "aws --version"
    config: |
      aws configure --profile local-dev
      # Use fake credentials for LocalStack
      AWS_ACCESS_KEY_ID=test
      AWS_SECRET_ACCESS_KEY=test
    notes: "Even for local development with LocalStack"
```

## Infrastructure as Code Tools

### Terraform Setup

```hcl
# Installation
# brew install terraform

# Verify installation
terraform version

# Local workspace structure
locals {
  dev_workspace = {
    path = "${path.root}/../terraform-local"
    environments = {
      local = {
        backend = "local"
        
        # LocalStack endpoint
        endpoints = {
          s3     = "http://localhost:4566"
          ec2    = "http://localhost:4566"
          rds    = "http://localhost:4566"
        }
      }
    }
  }
}

# Example: providers.tf for local development
terraform {
  backend "local" {
    path = "terraform-local.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
  
  # For LocalStack development
  endpoints {
    s3      = var.use_localstack ? "http://localhost:4566" : null
    ec2     = var.use_localstack ? "http://localhost:4566" : null
    rds     = var.use_localstack ? "http://localhost:4566" : null
    lambda  = var.use_localstack ? "http://localhost:4566" : null
  }
  
  skip_credentials_validation = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
}
```

### Ansible Setup

```yaml
# ~/.ansible.cfg
[defaults]
host_key_checking = False
inventory = ./inventory/hosts.yml
roles_path = ./roles
library = ./plugins/modules

# Local testing inventory
# inventory/hosts.yml
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
  
  children:
    local_dev:
      hosts:
        localhost:
      vars:
        env: development
        deployment_target: local

# Test playbook structure
---
- name: Local Development Test
  hosts: localhost
  gather_facts: yes
  
  tasks:
    - name: Validate Ansible setup
      debug:
        msg: "Ansible working on {{ inventory_hostname }}"
    
    - name: Check mode syntax validation
      command: "ansible-playbook --syntax-check site.yml"
      check_mode: yes
```

### Code Validation Tools

```bash
# Terraform linting and validation
brew install tflint
brew install terraform-docs

# Ansible linting
brew install ansible-lint

# YAML validation
brew install yamllint

# General linting setup
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/terraform-docs/terraform-docs
    rev: v0.16.0
    hooks:
      - id: terraform-docs-go
        args: [--sort-by-required]
  
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
  
  - repo: https://github.com/ansible/ansible-lint
    rev: v6.16.0
    hooks:
      - id: ansible-lint
  
  - repo: local
    hooks:
      - id: terraform-fmt
        name: Terraform format
        entry: terraform fmt -recursive
        language: system
        pass_filenames: false
EOF
```

## Container & Orchestration

### Docker Desktop Configuration

```yaml
docker_desktop_setup:
  
  resource_allocation:
    cpu:
      minimum: 4
      recommended: 6
      optimal: 8
      location: "Docker Desktop > Preferences > Resources"
    
    memory:
      minimum: 8
      recommended: 12
      optimal: 16-20
    
    disk:
      minimum: 50
      recommended: 100
      allocation: "Docker Desktop > Preferences > Disk"
    
    swap:
      enabled: true
      size: 2-4 GB
  
  networking:
    bridge_network: "docker0"
    dns_servers: ["8.8.8.8", "8.8.4.4"]
    config: |
      {
        "dns": ["8.8.8.8", "8.8.4.4"],
        "live-restore": true,
        "max-concurrent-downloads": 5
      }
```

### Local Kubernetes Setup

#### Option 1: Docker Desktop Kubernetes

```bash
# Enable Kubernetes in Docker Desktop
# Docker Desktop > Preferences > Kubernetes > Enable Kubernetes

# Verify
kubectl cluster-info
kubectl get nodes
kubectl get namespaces

# Context switching
kubectl config get-contexts
kubectl config use-context docker-desktop
```

#### Option 2: Kind (Kubernetes in Docker)

```bash
# Installation
brew install kind

# Create multi-node cluster
kind create cluster --name devops-local --config - << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
      - containerPort: 443
        hostPort: 443
  - role: worker
  - role: worker
featureGates:
  MeshTrafficPolicy: true
EOF

# Verify
kubectl cluster-info --context kind-devops-local
kind get clusters
```

#### Option 3: Minikube

```bash
# Installation
brew install minikube

# Start cluster
minikube start --driver=docker --cpus=4 --memory=8192

# Enable ingress addon
minikube addons enable ingress
minikube addons enable metrics-server

# Access dashboard
minikube dashboard

# Get IP
minikube ip
```

### Helm Setup

```bash
# Installation
brew install helm

# Add common repos
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Local chart testing
helm lint ./my-chart
helm template my-release ./my-chart
helm dry-run my-release ./my-chart

# Install locally
helm install my-release ./my-chart -n default --create-namespace
```

## Version Control & Collaboration

### Git Configuration

```bash
# Global configuration
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"
git config --global core.editor "vim"

# SSH key setup
ssh-keygen -t ed25519 -C "your.email@company.com" -f ~/.ssh/id_ed25519
ssh-add ~/.ssh/id_ed25519

# GitHub/GitLab configuration
# Add SSH key to GitHub: https://github.com/settings/keys
# Test connection
ssh -T git@github.com

# GPG signing (optional but recommended)
gpg --gen-key
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
```

### Git Workflow for DevOps

```yaml
local_git_workflow:
  
  branch_naming:
    feature: "feature/short-description"
    bugfix: "bugfix/issue-number"
    hotfix: "hotfix/short-description"
    
  commit_template: |
    # Type: feat|fix|docs|style|refactor|test|chore
    # Scope: (optional component)
    
    # Short description (50 chars max)
    # Longer description if needed
    
    # Closes: #123 (optional)
  
  pre_commit_hooks:
    - terraform fmt validation
    - ansible-lint
    - yamllint
    - No large binary files
    - No secrets/credentials
  
  workflow_example: |
    # Create feature branch
    git checkout -b feature/update-monitoring
    
    # Make changes
    git add .
    git commit -m "feat(monitoring): add new Prometheus scrape configs"
    
    # Push and create PR
    git push origin feature/update-monitoring
    
    # After review and approval
    git checkout main
    git pull origin main
    git merge --squash feature/update-monitoring
    git push origin main
```

## Local Database & Services

### Docker Compose Stack for Services

```yaml
# docker-compose.local.yml
version: '3.8'

services:
  
  # PostgreSQL
  postgres:
    image: postgres:15-alpine
    container_name: postgres-local
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: devops
      POSTGRES_PASSWORD: devops123
      POSTGRES_DB: devops_db
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U devops"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis
  redis:
    image: redis:7-alpine
    container_name: redis-local
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # MongoDB
  mongo:
    image: mongo:6
    container_name: mongo-local
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: devops
      MONGO_INITDB_ROOT_PASSWORD: devops123
    volumes:
      - mongo_data:/data/db
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  # LocalStack (AWS simulation)
  localstack:
    image: localstack/localstack:latest
    container_name: localstack
    ports:
      - "4566:4566"
      - "4571:4571"
    environment:
      SERVICES: s3,ec2,rds,lambda,sqs,sns,dynamodb
      DEBUG: 1
      DATA_DIR: /tmp/localstack/data
      LAMBDA_EXECUTOR: docker
      DOCKER_HOST: unix:///var/run/docker.sock
    volumes:
      - "${TMPDIR}:/tmp/localstack"
      - "/var/run/docker.sock:/var/run/docker.sock"
    healthcheck:
      test: ["CMD", "awslocal", "s3", "ls"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
  mongo_data:
```

### Service Management Script

```bash
#!/bin/bash
# scripts/services.sh - Manage local services

SERVICES_FILE="docker-compose.local.yml"

case "${1}" in
  start)
    docker-compose -f "$SERVICES_FILE" up -d
    echo "✅ Local services started"
    docker-compose -f "$SERVICES_FILE" ps
    ;;
  
  stop)
    docker-compose -f "$SERVICES_FILE" down
    echo "✅ Local services stopped"
    ;;
  
  restart)
    docker-compose -f "$SERVICES_FILE" restart
    echo "✅ Local services restarted"
    ;;
  
  logs)
    docker-compose -f "$SERVICES_FILE" logs -f "${2:-}"
    ;;
  
  health)
    echo "PostgreSQL:"
    docker-compose -f "$SERVICES_FILE" exec postgres pg_isready -U devops || echo "❌ Not ready"
    
    echo "Redis:"
    docker-compose -f "$SERVICES_FILE" exec redis redis-cli ping || echo "❌ Not ready"
    
    echo "MongoDB:"
    docker-compose -f "$SERVICES_FILE" exec mongo mongosh --eval "db.adminCommand('ping')" || echo "❌ Not ready"
    
    echo "LocalStack:"
    docker-compose -f "$SERVICES_FILE" exec localstack awslocal s3 ls || echo "❌ Not ready"
    ;;
  
  *)
    echo "Usage: $0 {start|stop|restart|logs|health}"
    exit 1
    ;;
esac
```

## Monitoring & Debugging

### Local Prometheus & Grafana

```yaml
# prometheus-local.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']  # cAdvisor
  
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']  # Node Exporter

# docker-compose additions
prometheus:
  image: prom/prometheus:latest
  ports:
    - "9090:9090"
  volumes:
    - ./prometheus-local.yml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.path=/prometheus'

grafana:
  image: grafana/grafana:latest
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin
    - GF_USERS_ALLOW_SIGN_UP=false
  volumes:
    - grafana_data:/var/lib/grafana
  depends_on:
    - prometheus
```

### Debugging Tools

```bash
# Installation
brew install dive              # Docker image analysis
brew install grpcurl          # gRPC debugging
brew install ktail            # Kubernetes log tailing
brew install kubectx          # Kubernetes context switching
brew install k9s              # Kubernetes TUI

# Container debugging
docker exec -it container_name /bin/sh
docker logs -f container_name

# Kubernetes debugging
kubectl logs pod_name -n namespace
kubectl describe pod pod_name
kubectl exec -it pod_name -- /bin/sh
kubectl port-forward pod_name 8080:8080

# Network debugging
docker network ls
docker inspect network_name
netstat -an | grep LISTEN
```

## IDE & Editor Setup

### VS Code for DevOps

```json
// settings.json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "files.exclude": {
    "**/.terraform": true,
    "**/venv": true
  },
  "[terraform]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true
  },
  "[yaml]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.insertSpaces": true,
    "editor.tabSize": 2
  },
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true
}
```

### Recommended VS Code Extensions

```json
{
  "extensions": [
    "hashicorp.terraform",           // Terraform support
    "redhat.vscode-yaml",            // YAML support
    "ansible.ansible",               // Ansible support
    "ms-kubernetes-tools.vscode-kubernetes-tools",  // Kubernetes
    "ms-azuretools.vscode-docker",   // Docker support
    "eamodio.gitlens",              // Git integration
    "ms-vscode-remote.remote-containers",  // Remote containers
    "ms-python.python",              // Python support
    "ms-python.vscode-pylance",      // Python linting
    "github.copilot",                // AI code completion
    "shellcheck.shellcheck",         // Shell script linting
    "dzhavat.bracket-pair-colorizer-2"  // Bracket matching
  ]
}
```

## Environment Automation

### Setup Script

```bash
#!/bin/bash
# scripts/setup-local-dev.sh

set -e

echo "🚀 Setting up local DevOps environment..."

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo -e "${RED}❌ $1 not found${NC}"
    return 1
  fi
  echo -e "${GREEN}✅ $1 installed${NC}"
}

check_command "git"
check_command "docker"
check_command "brew"

# Install core tools
echo -e "${YELLOW}Installing DevOps tools...${NC}"

TOOLS=(
  "terraform"
  "ansible"
  "kubectl"
  "helm"
  "awscli"
  "jq"
  "yq"
  "yamllint"
  "ansible-lint"
  "tflint"
  "kind"
)

for tool in "${TOOLS[@]}"; do
  if ! command -v "$tool" &> /dev/null; then
    echo "Installing $tool..."
    brew install "$tool"
  else
    echo -e "${GREEN}✅ $tool already installed${NC}"
  fi
done

# Configure Git
echo -e "${YELLOW}Configuring Git...${NC}"
git config --global core.editor "vim"
git config --global pull.rebase true

# Setup SSH keys
if [ ! -f ~/.ssh/id_ed25519 ]; then
  echo -e "${YELLOW}Generating SSH key...${NC}"
  ssh-keygen -t ed25519 -C "$(git config user.email)" -f ~/.ssh/id_ed25519 -N ""
else
  echo -e "${GREEN}✅ SSH key exists${NC}"
fi

# Start local services
echo -e "${YELLOW}Starting local services...${NC}"
docker-compose -f docker-compose.local.yml up -d

# Enable Kubernetes in Docker Desktop
echo -e "${YELLOW}Checking Kubernetes in Docker...${NC}"
if ! kubectl cluster-info &> /dev/null; then
  echo "⚠️  Please enable Kubernetes in Docker Desktop preferences"
else
  echo -e "${GREEN}✅ Kubernetes enabled${NC}"
fi

# Verify setup
echo -e "${YELLOW}Verifying installation...${NC}"

echo "Git:"
git --version

echo "Docker:"
docker --version

echo "Kubernetes:"
kubectl version --client

echo "Terraform:"
terraform version

echo "Ansible:"
ansible --version

echo -e "${GREEN}✅ Local DevOps environment setup complete!${NC}"
```

## Performance Optimization

### Optimization Tips

```yaml
performance_optimization:
  
  docker_desktop:
    memory_limit: "Allocate 50% of available RAM"
    cpu_limit: "Allocate 50-75% of available cores"
    disk_cache: "Enable on SSD"
    network: "Use bridge network for better performance"
  
  kubernetes:
    resource_requests: |
      Set appropriate requests/limits:
      - CPU: 100m-500m for development pods
      - Memory: 128Mi-512Mi for development pods
    node_resources: "Monitor via 'kubectl top nodes'"
    
  volumes:
    avoid_mounted_volumes: "Use named volumes when possible"
    mount_performance: |
      Mounted volumes on Docker Desktop are slow:
      - Use volume mounts for databases
      - Use bind mounts only for source code
    
  caching:
    docker_layer_caching: "Use .dockerignore aggressively"
    terraform_caching: "Use -cache-dir flag"
    ansible_caching: "Enable fact caching"

  monitoring:
    check_resources: "docker stats"
    prune_regularly: "docker system prune -a"
```

### Cleanup Script

```bash
#!/bin/bash
# scripts/cleanup.sh

echo "🧹 Cleaning up local environment..."

# Stop services
docker-compose -f docker-compose.local.yml down

# Remove unused images
echo "Removing unused Docker images..."
docker image prune -a -f

# Remove unused volumes
echo "Removing unused volumes..."
docker volume prune -f

# Remove unused networks
echo "Removing unused networks..."
docker network prune -f

# Remove Terraform cache
echo "Cleaning Terraform cache..."
find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.tfstate*" -delete 2>/dev/null || true

# Remove Python cache
echo "Cleaning Python cache..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true

echo "✅ Cleanup complete!"
```

## Security Considerations

### Local Development Security

```yaml
security_best_practices:
  
  secrets_management:
    avoid: "Never commit secrets or credentials"
    use_instead: |
      - .env files (git-ignored)
      - Environment variables
      - HashiCorp Vault
      - AWS Secrets Manager
    
    example_gitignore: |
      .env
      .env.local
      *.tfvars
      terraform.tfstate
      terraform.tfstate.*
      ~/.aws/credentials
      ~/.kube/config
  
  ssh_keys:
    generation: "ssh-keygen -t ed25519"
    permissions: "chmod 600 ~/.ssh/id_ed25519"
    add_to_agent: "ssh-add ~/.ssh/id_ed25519"
    never_commit: "Add to .gitignore"
  
  docker_security:
    scan_images: "docker scan image_name"
    use_non_root: "Run containers as non-root user"
    resource_limits: "Always set resource limits"
  
  kubernetes_rbac:
    default_deny: "Set default DENY network policies"
    pod_security: "Use Pod Security Policies"
    secrets: "Use sealed-secrets or external-secrets"
```

### Pre-commit Hooks Setup

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: detect-private-key
      - id: check-added-large-files
        args: ['--maxkb=1000']

  - repo: https://github.com/terraform-docs/terraform-docs
    rev: v0.16.0
    hooks:
      - id: terraform-docs-go
        args: [--sort-by-required]

  - repo: https://github.com/ansible/ansible-lint
    rev: v6.16.0
    hooks:
      - id: ansible-lint
        args: [--fix]
```

## Troubleshooting

### Common Issues

```yaml
common_issues:
  
  docker_disk_full:
    symptoms: "Docker operations fail with disk space error"
    solution: |
      docker system prune -a
      # Or increase Docker Desktop disk allocation
  
  kubernetes_context_lost:
    symptoms: "kubectl commands fail after Docker restart"
    solution: |
      kubectl config use-context docker-desktop
      # Or verify: docker-compose ps
  
  port_conflicts:
    symptoms: "Port already in use errors"
    solution: |
      # Find process using port
      lsof -i :8080
      # Kill or change port in docker-compose
      docker-compose -f docker-compose.local.yml down
  
  terraform_state_conflicts:
    symptoms: "Terraform state locking issues"
    solution: |
      rm -f terraform.tfstate.lock.hcl
      terraform refresh
  
  ansible_inventory_not_found:
    symptoms: "Inventory file not readable"
    solution: |
      Check ~/.ansible.cfg
      Verify inventory path
      ansible-inventory --list
  
  slow_performance:
    symptoms: "Everything feels sluggish"
    solution: |
      1. Check Docker Desktop resources
      2. Run: docker stats
      3. Prune unused images/volumes
      4. Restart Docker
      5. Check host system resources
```

---

## Quick Reference Checklist

### Day 1 Setup

- [ ] Install Homebrew (if not present)
- [ ] Install Git and configure SSH keys
- [ ] Install Docker Desktop
- [ ] Enable Kubernetes in Docker Desktop
- [ ] Install essential CLI tools (kubectl, helm, terraform, ansible)
- [ ] Start local services (PostgreSQL, Redis, LocalStack)
- [ ] Clone project repositories
- [ ] Run `scripts/setup-local-dev.sh`

### Weekly Maintenance

- [ ] Update Homebrew packages: `brew upgrade`
- [ ] Pull latest Docker images: `docker pull`
- [ ] Clean up unused resources: `docker system prune`
- [ ] Review and rotate SSH keys if needed
- [ ] Check for security updates

### Monthly Deep Dive

- [ ] Review and optimize resource allocation
- [ ] Update all development tools
- [ ] Test full local CI/CD pipeline simulation
- [ ] Review secrets management practices
- [ ] Archive and backup local databases

---

## Best Practices Summary

✅ **Do:**
- Use Docker Compose for reproducible local environments
- Version all tools in `.tool-versions` or similar
- Automate environment setup with scripts
- Use different contexts for different environments
- Keep local environment close to production
- Document environment-specific configurations
- Use pre-commit hooks for validation
- Regularly clean up unused resources
- Test changes in Kind/Minikube before pushing
- Rotate SSH keys every 6-12 months

❌ **Don't:**
- Run production services locally
- Commit secrets or credentials
- Use localhost as production hostname
- Skip security scanning in local environment
- Over-allocate resources to Docker Desktop
- Use old, unmaintained development tool versions
- Ignore local logs and errors
- Test only on main branch
- Use admin/root for development
- Skip environment documentation

---

**Note**: This guide is current as of December 2025. Local development environments should closely mirror production to catch issues early. Regularly update your local tools to stay current with production versions.

For the latest updates and community contributions, refer to the [Enterprise Automation Handbook](https://github.com/diceone/Enterprise-Automation-Handbook).
