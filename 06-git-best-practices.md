# Git Best Practices

A comprehensive guide covering version control, branching strategies, commit management, and collaboration workflows for infrastructure automation teams.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Core Concepts](#core-concepts)
3. [Branching Strategy](#branching-strategy)
4. [Commit Management](#commit-management)
5. [Collaboration & Code Review](#collaboration--code-review)
6. [Merge Strategies](#merge-strategies)
7. [Repository Management](#repository-management)
8. [Security & Access Control](#security--access-control)
9. [CI/CD Integration](#cicd-integration)
10. [Troubleshooting](#troubleshooting)

---

## Project Structure

### Repository Organization

```
infrastructure-repo/
├── .github/
│   ├── workflows/              # GitHub Actions
│   ├── CODEOWNERS             # Code ownership rules
│   ├── pull_request_template.md
│   └── issue_template/
├── .gitignore                  # Git ignore rules
├── .gitattributes             # Line ending rules
├── README.md                   # Main documentation
├── CONTRIBUTING.md            # Contribution guidelines
├── ansible/                    # Ansible playbooks
│   ├── playbooks/
│   ├── roles/
│   └── inventory/
├── terraform/                  # Terraform configurations
│   ├── environments/
│   ├── modules/
│   └── global/
├── kubernetes/                 # Kubernetes manifests
│   ├── base/
│   └── overlays/
└── docs/                       # Documentation
    ├── runbooks/
    └── architecture/
```

### Repository Initialization

```bash
# Initialize repository with proper configuration
git init
git config user.name "DevOps Team"
git config user.email "devops@example.com"

# Add essential files
echo "# Infrastructure as Code" > README.md
cat > .gitignore << 'EOF'
# Sensitive files
*.tfvars
*.pem
*.key
.env
secrets/
vault/

# Generated files
*.tfstate
*.tfstate.*
.terraform/
dist/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
EOF

# Add .gitattributes for consistency
cat > .gitattributes << 'EOF'
* text=auto
*.sh text eol=lf
*.yaml text eol=lf
*.yml text eol=lf
*.json text eol=lf
*.tf text eol=lf
*.md text eol=lf
*.exe binary
EOF

git add .
git commit -m "chore: initialize repository with .gitignore and .gitattributes"
```

---

## Core Concepts

### Git Workflow Essentials

#### 1. Authentication

**SSH Keys (Recommended)**
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "devops@example.com" -f ~/.ssh/id_ed25519

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Test connection
ssh -T git@github.com
```

**Personal Access Tokens**
```bash
# Create token with appropriate scopes
# Scopes: repo, read:org, write:packages

# Use token for authentication
git clone https://token@github.com/myorg/repo.git
```

#### 2. Configuration Management

```bash
# Global configuration
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global core.editor "vim"
git config --global init.defaultBranch "main"

# Repository-specific configuration
git config user.name "Team Name"
git config user.email "team@example.com"

# View configuration
git config --list
git config --list --local
```

#### 3. Working with Remotes

```bash
# Add remote repository
git remote add origin https://github.com/myorg/infrastructure.git

# List remotes
git remote -v

# Fetch updates
git fetch origin

# Pull with rebase (cleaner history)
git config pull.rebase true

# Set upstream for branch
git push -u origin feature/branch-name
```

---

## Branching Strategy

### Git Flow

Recommended for infrastructure projects with planned releases.

```
main (production)
  ↑
  ├── release/v1.0.0
  │   ├── hotfix/critical-bug
  │   └── merge to main + develop
  │
develop (staging)
  ↑
  ├── feature/new-feature
  ├── feature/improve-performance
  └── bugfix/issue-123
```

**Implementation**

```bash
# Initialize git flow
git flow init

# Create feature branch
git flow feature start new-feature

# Finish feature (merges to develop)
git flow feature finish new-feature

# Create release branch
git flow release start 1.0.0

# Finish release (merges to main + develop)
git flow release finish 1.0.0

# Create hotfix
git flow hotfix start critical-fix
git flow hotfix finish critical-fix
```

### Trunk-Based Development

Recommended for CI/CD heavy environments with continuous deployment.

```
main (always deployable)
  ↑
  ├── feature/short-lived-branch-1
  ├── feature/short-lived-branch-2
  └── feature/short-lived-branch-3
```

**Implementation**

```bash
# Create short-lived feature branch
git checkout -b feature/issue-123-add-validation

# Small, focused changes
# Submit PR after 1-2 days max

# Merge to main
git merge --squash feature/issue-123-add-validation
git push origin main
```

### Branch Naming Conventions

```bash
# Feature branch
feature/add-database-encryption
feature/DEVOPS-123-kubernetes-upgrade

# Bugfix branch
bugfix/fix-memory-leak
bugfix/INFRA-456-terraform-state-issue

# Release branch
release/v1.2.0
release/ansible-2.10

# Hotfix branch
hotfix/critical-security-fix
hotfix/production-downtime-fix

# Documentation branch
docs/add-runbook
docs/update-architecture-guide

# Chore/maintenance branch
chore/update-dependencies
chore/refactor-common-module
```

### Branch Protection Rules

```yaml
# GitHub example
branch_protection_rules:
  main:
    require_pull_request_reviews: true
    required_review_count: 2
    require_status_checks: true
    require_branches_to_be_up_to_date: true
    dismiss_stale_reviews: false
    require_code_owner_reviews: true
  
  develop:
    require_pull_request_reviews: true
    required_review_count: 1
    require_status_checks: true
```

---

## Commit Management

### Commit Message Format

**Organization Standard: [JIRAID] Conventional Commits**

Our commit format combines JIRA ticket IDs with Conventional Commits:

```
[JIRAID] <type>(<scope>): <subject>

<body>

<footer>
```

**Example**
```
[DEVOPS-123] feat(ansible): add firewall configuration to common role

Add comprehensive firewall rules to the common role for
standardized host security across all environments.

- Configure UFW for dev/staging environments
- Configure firewalld for production
- Add variables for port customization

Closes #456
```

**Types**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Code style changes
- `refactor` - Code refactoring
- `perf` - Performance improvement
- `test` - Test additions/changes
- `chore` - Build/dependency updates
- `ci` - CI/CD changes
- `infrastructure` - Infrastructure changes
- `infrastructure` - Infrastructure changes

### Examples

```bash
# Simple fix with JIRAID
git commit -m "[DEVOPS-100] fix(ansible): correct syntax in common role"

# Feature with body
git commit -m "[DEVOPS-101] feat(terraform): add multi-region support

- Add provider aliases for regions
- Update variables for regional config
- Add cross-region replication

Closes #123"

# Breaking change with JIRAID
git commit -m "[PLATFORM-102] feat(kubernetes)!: migrate to v1.24 API

BREAKING CHANGE: Deprecated v1beta1 APIs removed
Old manifests require migration to v1"

# Infrastructure change with JIRAID
git commit -m "[INFRA-103] infrastructure(ci-cd): upgrade to GitLab Runner 15.0

- Update runner Docker image
- Add new executor options
- Configure resource limits"
```

### Commit Best Practices

**Organization-Specific Format: [JIRAID] Commit Message**

Our commits follow the format: `[JIRAID] commit message`, where JIRAID is the Jira ticket ID.

```bash
# Basic format with JIRAID
git commit -m "[DEVOPS-123] feat(ansible): add firewall configuration to common role"

# With description body
git commit -m "[INFRA-456] fix(terraform): correct VPC CIDR validation

- Update CIDR validation logic
- Add IPv6 support
- Fix edge case for /32 subnets

Closes #789"

# Breaking change with JIRAID
git commit -m "[PLATFORM-789] feat(kubernetes)!: migrate to v1.24 API

BREAKING CHANGE: Deprecated v1beta1 APIs removed
Old manifests require migration to v1"

# Multiple issues
git commit -m "[DEVOPS-111] [DEVOPS-222] fix(ci-cd): resolve pipeline timeout

- Increase timeout threshold
- Optimize parallel job execution
- Add logging for debugging"
```

**Format Breakdown**

| Component | Format | Example |
|-----------|--------|---------|
| JIRA ID | [JIRAID] | [DEVOPS-123] |
| Type | type(scope) | feat(ansible), fix(terraform) |
| Message | Clear, imperative | add firewall config, fix state issue |
| Body | Optional details | Change descriptions, reasoning |
| Footer | Optional metadata | Closes #789, BREAKING CHANGE |

**Examples by Type**

```bash
# Feature
[DEVOPS-101] feat(ansible): add nginx role with ssl support

# Bug fix
[INFRA-202] fix(terraform): correct IAM policy syntax

# Documentation
[DOCS-303] docs(kubernetes): add deployment troubleshooting guide

# Infrastructure change
[PLATFORM-404] infrastructure(cicd): upgrade runner version

# Performance improvement
[OPS-505] perf(ansible): optimize large inventory processing

# Test addition
[QA-606] test(terraform): add validation for output variables

# Chore/maintenance
[MAINT-707] chore(dependencies): update ansible to 2.12

# Security fix
[SEC-808] fix(github): rotate authentication tokens and update secrets

# Multi-scope change
[ARCH-909] refactor(kubernetes,terraform): consolidate resource definitions
```

**Best Practices**

```bash
# ✅ DO - Use imperative mood, JIRAID, clear message
[DEVOPS-123] feat(ansible): add database backup role
git commit -m "[DEVOPS-123] feat(ansible): add database backup role"

# ❌ DON'T - Skip JIRAID, use past tense
git commit -m "Added database backup role"

# ✅ DO - Reference related tickets
git commit -m "[DEVOPS-123] feat(ansible): add database backup role

Closes #456
Related to [DEVOPS-124]"

# ✅ DO - Explain why, not just what
git commit -m "[INFRA-789] fix(terraform): increase timeout threshold

Increased from 5m to 10m to prevent timeout errors
on large deployments with 50+ servers"

# ❌ DON'T - Vague or missing JIRAID
git commit -m "various fixes and updates"

# ✅ DO - Use body for complex changes
git commit -m "[PLATFORM-555] feat(kubernetes): implement pod security policies

- Add restricted PSP for standard workloads
- Add baseline PSP for legacy apps
- Add privileged PSP for system components
- Update RBAC to bind PSPs correctly"
```

### Atomic Commits (one logical change)

```bash
git add ansible/roles/common/tasks/main.yml
git commit -m "[DEVOPS-100] feat(ansible): add firewall configuration to common role"

git add ansible/roles/common/defaults/main.yml
git commit -m "[DEVOPS-100] feat(ansible): add firewall variables with sensible defaults"
```

# Stage specific lines (avoid staging unrelated changes)
git add -p
# Review and stage specific hunks

# Amend last commit (before pushing)
git commit --amend --no-edit
git commit --amend -m "new message"

# Undo last commit (keep changes)
git reset --soft HEAD~1

# View commit history
git log --oneline --graph --decorate --all
git log --author="name" --since="2025-01-01" --until="2025-12-31"
git log -p --follow -- path/to/file  # History of file
```

### Commit Size Guidelines

| Size | Impact | Recommendation |
|------|--------|-----------------|
| < 100 lines | Small change | Ideal for single commits |
| 100-300 lines | Moderate change | Single logically cohesive commit |
| 300-500 lines | Large change | Consider splitting into logical commits |
| > 500 lines | Very large | Split into multiple commits |

---

## Collaboration & Code Review

### Pull Request Process

```bash
# 1. Create feature branch
git checkout -b feature/add-monitoring

# 2. Make changes and commit
git add ansible/roles/monitoring/
git commit -m "feat(ansible): add prometheus monitoring role"

# 3. Push to remote
git push -u origin feature/add-monitoring

# 4. Create Pull Request
# - Provide clear title and description
# - Reference related issues
# - Add labels and assignees

# 5. Address review comments
git add .
git commit -m "feedback: update monitoring config based on review"
git push origin feature/add-monitoring

# 6. Merge when approved
git checkout main
git pull origin main
git merge feature/add-monitoring --no-ff
git push origin main

# 7. Delete feature branch
git branch -d feature/add-monitoring
git push origin --delete feature/add-monitoring
```

### Pull Request Template

```markdown
# Description
Brief description of the changes.

## Related Issue
Closes #123

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Infrastructure change
- [ ] Documentation update

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests passed
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style
- [ ] Documentation updated
- [ ] No breaking changes
- [ ] Secrets not committed
- [ ] YAML/JSON validated
```

### Code Review Best Practices

**For Reviewers**
```bash
# Fetch PR branch
git fetch origin pull/123/head:pr-123
git checkout pr-123

# Test locally
ansible-lint
terraform validate
kubectl apply --dry-run=client

# Review suggestions inline
# Approve with changes if minor improvements needed
# Request changes if substantial issues found
```

**For Authors**
```bash
# Keep PR focused (< 400 lines)
# Respond to all comments
# Request re-review after changes
# Avoid force pushes after review starts (git push --force-with-lease)
```

---

## Merge Strategies

### Merge Commit

Preserves full history and branch information.

```bash
git merge feature/branch --no-ff

# Result: Explicit merge commit visible in history
```

**Use for:**
- Long-running feature branches
- Multi-person collaboration
- Want complete history preserved

### Squash Merge

Combines all commits into one clean commit.

```bash
git merge feature/branch --squash
git commit -m "feat: add new monitoring system"

# Result: Single clean commit, history hidden
```

**Use for:**
- Small features/fixes
- Many work-in-progress commits
- Want clean main branch history

### Rebase Merge

Linear history without merge commits.

```bash
git rebase main
git merge feature/branch --ff-only

# Result: Linear history, no merge commit
```

**Use for:**
- Trunk-based development
- Want linear history
- Small isolated changes

### Recommended Strategy per Project Type

| Project | Strategy | Reason |
|---------|----------|--------|
| Infrastructure IaC | Squash | Clean, reviewable commits |
| Monorepo | Merge commit | Preserve component history |
| Microservices | Rebase | Linear deployment history |
| Documentation | Squash | Minimal commit noise |

---

## Repository Management

### Housekeeping

```bash
# Remove stale branches locally
git branch -d branch-name

# Remove stale remote branches
git push origin --delete branch-name

# Prune tracking branches
git fetch --prune

# Garbage collection
git gc --aggressive

# Find large files
git rev-list --all --objects | sed 's/ .*//' | \
  sort -u | while read object; do
    git cat-file -s "$object"
  done | sort -rn | head -20
```

### Tag Management

```bash
# Create annotated tag (recommended)
git tag -a v1.0.0 -m "Release version 1.0.0"

# Create lightweight tag
git tag v1.0.0

# List tags
git tag -l
git tag -l "v1.*"

# Show tag details
git show v1.0.0

# Push tags
git push origin v1.0.0
git push origin --tags

# Delete local tag
git tag -d v1.0.0

# Delete remote tag
git push origin --delete v1.0.0
```

### Release Management

```bash
# Create release branch
git checkout -b release/v1.0.0 develop

# Update version numbers
# Update CHANGELOG
git commit -am "chore: bump version to 1.0.0"

# Tag release
git tag -a v1.0.0 -m "Release v1.0.0"

# Merge to main
git checkout main
git merge release/v1.0.0 --no-ff

# Merge back to develop
git checkout develop
git merge release/v1.0.0 --no-ff

# Push
git push origin main develop --tags

# Delete release branch
git branch -d release/v1.0.0
```

---

## Security & Access Control

### SSH Key Management

```bash
# Generate key with passphrase
ssh-keygen -t ed25519 -C "devops@example.com" -f ~/.ssh/id_ed25519

# Add to SSH agent with timeout
ssh-add -t 3600 ~/.ssh/id_ed25519

# View public key
cat ~/.ssh/id_ed25519.pub

# Rotate keys regularly
# Archive old keys
# Update in Git hosting platform
```

### Secrets Management

```bash
# NEVER commit secrets
git rm --cached secrets.txt
echo "secrets.txt" >> .gitignore
git commit -m "remove: accidentally committed secrets"
git push

# Use git-crypt for encrypted files
git crypt init

# Use sealed secrets for Kubernetes
kubectl apply -f sealed-secret.yaml

# Use AWS Secrets Manager / Azure KeyVault
terraform apply -var-file=secrets.tfvars  # Not in repo
```

### Access Control

```yaml
# GitHub CODEOWNERS file
# Require code owner approval

# Infrastructure files
infrastructure/ @devops-team
terraform/ @terraform-team
ansible/ @ansible-team
kubernetes/ @platform-team

# Critical paths
*.tfvars @security-team
secrets/ @security-team
.github/ @devops-lead

# Specific roles
ansible/roles/security/ @security-team
terraform/modules/iam/ @security-team
```

### Audit & Compliance

```bash
# View commit history with author
git log --pretty=format:"%h %an %ad %s" --date=short

# Find commits by author
git log --author="name" --oneline

# View all changes in time range
git log --since="2025-01-01" --until="2025-12-31"

# Track branch history
git reflog

# Show who changed what
git blame path/to/file
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Infrastructure CI/CD

on:
  pull_request:
    paths:
      - 'ansible/**'
      - 'terraform/**'
      - 'kubernetes/**'
  push:
    branches: [main, develop]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate Terraform
        run: |
          cd terraform
          terraform init -backend=false
          terraform validate
      
      - name: Lint Ansible
        run: ansible-lint ansible/
      
      - name: Validate Kubernetes
        run: |
          kubectl apply -f kubernetes/ --dry-run=client
```

### Commit Hooks

```bash
# Install pre-commit framework
pip install pre-commit

# Create .pre-commit-config.yaml
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: check-yaml
      - id: check-json
      - id: detect-private-key
  
  - repo: https://github.com/hadialqattan/pycln
    rev: v2.1.3
    hooks:
      - id: pycln
  
  - repo: https://github.com/ansible/ansible-lint
    rev: v6.8.7
    hooks:
      - id: ansible-lint
EOF

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Accidentally Committed Sensitive Data

```bash
# If not yet pushed
git reset --soft HEAD~1
git restore --staged sensitive-file.txt
echo "sensitive-file.txt" >> .gitignore
git add .gitignore
git commit -m "remove: accidentally committed sensitive file"

# If already pushed (use git-filter-branch or BFG)
git filter-branch --tree-filter 'rm -f secrets.txt' HEAD

# Force push to remove from history
git push origin main --force-with-lease
```

#### 2. Merge Conflicts

```bash
# View conflicts
git status

# View conflict details
git diff

# Resolve conflicts manually in editor
# Then:
git add resolved-file.txt
git commit -m "resolve: merge conflict in resolved-file.txt"
git push

# Abort merge
git merge --abort
```

#### 3. Accidental Force Push

```bash
# View reflog to find lost commits
git reflog

# Recover branch
git reset --hard <commit-sha>
git push origin main --force-with-lease
```

#### 4. Wrong Branch Push

```bash
# Undo last push (not yet merged)
git push origin +main:feature/wrong-branch  # Revert

# Better: prevent with branch protection rules
# or use:
git config push.default current  # Only push current branch
```

#### 5. Large File Accidentally Committed

```bash
# Use BFG Repo-Cleaner
bfg --delete-files large-file.iso

# Or git-filter-branch
git filter-branch --tree-filter 'rm -f large-file' HEAD

# Force push
git push origin main --force-with-lease
```

### Useful Debugging Commands

```bash
# See what changed
git diff main feature/branch
git diff HEAD~3..HEAD

# Check out file from specific commit
git show commit-sha:path/to/file > path/to/file

# Find commit that introduced a bug
git bisect start
git bisect bad main
git bisect good v1.0.0
# Test commits, mark good/bad

# View changes for specific author
git log --author="name" --stat

# See who deleted a line
git log -S "line content" -p

# Revert specific commit
git revert commit-sha
git push

# Cherry-pick commit from another branch
git cherry-pick commit-sha
```

---

## Best Practices Summary

✅ **Branching**
- Use meaningful branch names
- Keep branches short-lived (< 1 week)
- Delete merged branches
- Use branch protection rules

✅ **Commits**
- Use conventional commit format
- Keep commits small and focused
- Write descriptive messages
- Never force push main branch

✅ **Collaboration**
- Require code reviews
- Request changes clearly
- Respond to feedback promptly
- Test locally before push

✅ **Security**
- Use SSH keys for authentication
- Never commit secrets
- Rotate credentials regularly
- Review access control regularly

✅ **Repository Health**
- Maintain clean commit history
- Tag releases with semver
- Keep dependencies updated
- Archive old branches

✅ **Documentation**
- Document branching strategy
- Maintain CONTRIBUTING.md
- Add team guidelines to README
- Keep runbooks in repo

---

## References

- [Git Official Documentation](https://git-scm.com/doc)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)
- [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/)
- [Trunk-Based Development](https://trunkbaseddevelopment.com/)
- [Pre-commit Framework](https://pre-commit.com/)
- [GitHub Security Best Practices](https://docs.github.com/en/code-security)

---

**Version**: 1.0
**Author**: Michael Vogeler  
**Last Updated**: December 2025
**Maintained By**: DevOps Team
