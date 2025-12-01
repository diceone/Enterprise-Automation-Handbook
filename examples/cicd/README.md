# CI/CD Examples

Complete CI/CD pipeline implementations for GitLab CI and Jenkins.

## Files Overview

- `.gitlab-ci.yml` - GitLab CI pipeline configuration
- `Jenkinsfile` - Jenkins declarative pipeline
- `docker-compose.test.yml` - Testing environment setup (optional)

## GitLab CI Pipeline

### Stages

1. **build** - Build Docker image
2. **test** - Unit, integration, and code quality tests
3. **push** - Push image to registry
4. **deploy** - Deploy to staging and production

### Quick Start

```bash
# Trigger pipeline on push to main branch
git push origin main

# Trigger pipeline on tag
git tag v1.0.0
git push origin v1.0.0
```

### Variables Setup

Required CI/CD variables in GitLab:

```bash
KUBE_CONFIG_STAGING      # Base64 encoded kubeconfig
KUBE_CONFIG_PRODUCTION   # Base64 encoded kubeconfig
CI_REGISTRY_USER         # Registry username
CI_REGISTRY_PASSWORD     # Registry password
```

### Key Features

✅ Multi-stage pipeline
✅ Parallel test execution
✅ Code coverage reporting
✅ Security scanning
✅ Blue-green deployment
✅ Manual approval gates
✅ Rollback capability

## Jenkins Pipeline

### Requirements

```bash
# Jenkins plugins
- Docker Pipeline
- Kubernetes
- JUnit Plugin
- HTML Publisher Plugin
- Mail Extension Plugin
```

### Setup

```groovy
// Initialize Jenkins job
1. Create new Pipeline job
2. Configure GitHub repository
3. Set build triggers (polling, webhooks)
4. Add credentials for Docker registry
5. Add credentials for Kubernetes config
```

### Execution

```bash
# Manual build
curl -X POST http://jenkins:8080/job/myapp/build

# With parameters
curl -X POST http://jenkins:8080/job/myapp/buildWithParameters \
  -d "ENVIRONMENT=production" \
  -d "RUN_TESTS=true"
```

### Key Features

✅ Parametrized builds
✅ Parallel execution
✅ Build artifacts archiving
✅ Test result reporting
✅ Email notifications
✅ Manual approval gates
✅ Security scanning with Trivy

## Common Workflows

### Staging Deployment

**GitLab:**
```bash
git push origin main
# Pipeline auto-deploys to staging
```

**Jenkins:**
```bash
# Manual trigger with staging parameter
curl -X POST http://jenkins:8080/job/myapp/buildWithParameters \
  -d "ENVIRONMENT=staging"
```

### Production Deployment

**GitLab:**
```bash
# Create release tag
git tag v1.0.0
git push origin v1.0.0
# Pipeline requires manual approval
# Click "deploy_production" to deploy
```

**Jenkins:**
```bash
# Create release branch
git checkout -b release/v1.0.0
git push origin release/v1.0.0
# Pipeline auto-triggers
# Requires manual approval at deployment stage
```

### Rollback

**GitLab:**
```bash
# Manual rollback job
# Click "rollback_production" in pipeline
```

**Jenkins:**
```bash
# Restart previous build
curl -X POST http://jenkins:8080/job/myapp/[BUILD_NUMBER]/replay
```

## Environment Configuration

### Staging

```yaml
environment: staging
url: https://staging.example.com
strategy: canary  # 10% of traffic
```

### Production

```yaml
environment: production
url: https://app.example.com
strategy: blue-green  # Zero-downtime deployment
```

## Testing Strategy

### Unit Tests

```bash
# Run unit tests
pytest tests/unit --cov=app

# Coverage requirement: 80%
```

### Integration Tests

```bash
# Start test environment
docker-compose -f docker-compose.test.yml up -d

# Run tests
docker-compose exec app pytest tests/integration

# Cleanup
docker-compose down
```

### Smoke Tests

```bash
# Post-deployment tests
curl https://app.example.com/health
curl https://app.example.com/api/status
```

## Security Scanning

### Bandit (Python)

```bash
bandit -r app -f json -o bandit.json
```

### Trivy (Container Images)

```bash
trivy image myregistry.azurecr.io/myapp:v1.0.0
```

### Safety (Dependencies)

```bash
safety check --json
```

## Artifact Management

### Build Artifacts

```bash
# Docker images
${REGISTRY}/${CI_PROJECT_PATH}:${CI_COMMIT_SHORT_SHA}
${REGISTRY}/${CI_PROJECT_PATH}:latest
```

### Test Reports

```bash
# JUnit reports
test-results.xml

# Coverage reports
coverage.xml
htmlcov/

# Code quality
pylint.txt
flake8.json
```

## Troubleshooting

### Build Failed

```bash
# Check build logs
curl https://gitlab.com/api/v4/projects/ID/pipelines/PIPELINE_ID/jobs

# Re-run failed job
# In GitLab: Click "Retry" button
```

### Test Failure

```bash
# Check test output
docker logs <test-container>

# Run tests locally
pytest tests/ -v
```

### Deploy Failure

```bash
# Check deployment status
kubectl rollout status deployment/myapp

# View events
kubectl get events --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs deployment/myapp
```

### Registry Authentication

```bash
# Test registry access
docker login registry.example.com

# Check credentials in pipeline
echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin
```

## Best Practices

✅ Always run tests before deployment
✅ Use semantic versioning for releases
✅ Implement manual approval for production
✅ Monitor deployment metrics
✅ Keep pipeline cache size under control
✅ Archive test and coverage reports
✅ Set appropriate timeout values
✅ Use environment-specific credentials
✅ Implement rollback capability
✅ Document pipeline configuration

## References

- [GitLab CI Documentation](https://docs.gitlab.com/ee/ci/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [CI/CD Best Practices Guide](../04-cicd-best-practices.md)
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
