# CI/CD Pipeline Best Practices

A comprehensive guide for DevOps Engineers on implementing continuous integration and continuous deployment pipelines reliably and securely.

## Table of Contents

1. [Pipeline Architecture](#pipeline-architecture)
2. [Version Control Strategy](#version-control-strategy)
3. [Build Process](#build-process)
4. [Testing Strategy](#testing-strategy)
5. [Artifact Management](#artifact-management)
6. [Deployment Strategies](#deployment-strategies)
7. [Environment Management](#environment-management)
8. [Pipeline as Code](#pipeline-as-code)
9. [Security in CI/CD](#security-in-cicd)
10. [Monitoring and Observability](#monitoring-and-observability)
11. [Scaling and Performance](#scaling-and-performance)
12. [Disaster Recovery](#disaster-recovery)

---

## Pipeline Architecture

### Recommended CI/CD Flow

```
Source Code → Build → Test → Scan → Deploy Dev → Deploy Staging → Deploy Prod
     ↓          ↓       ↓      ↓        ↓           ↓               ↓
  Commit      Docker  Unit   SAST    Smoke      Integration      Canary
             Image    Tests  DAST    Tests      Tests            Rollout
```

### Pipeline Stages

```yaml
---
# GitLab CI/CD example (generic CI/CD patterns)
stages:
  - build
  - test
  - security
  - deploy-dev
  - deploy-staging
  - deploy-prod
  - rollback

build:
  stage: build
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA
  only:
    - branches

test:unit:
  stage: test
  script:
    - npm install
    - npm run test:unit
  coverage: '/Coverage: \d+\.\d+%/'

test:integration:
  stage: test
  script:
    - docker-compose up -d
    - npm run test:integration
    - docker-compose down
  when: on_success

security:sast:
  stage: security
  script:
    - sonarqube-scanner
  allow_failure: true

security:dast:
  stage: security
  script:
    - owasp-zap-scan $STAGING_URL
  only:
    - main
  when: on_success

deploy:dev:
  stage: deploy-dev
  script:
    - kubectl set image deployment/app app=$IMAGE_NAME:$CI_COMMIT_SHA -n development
    - kubectl rollout status deployment/app -n development
  environment:
    name: development
    url: https://dev.example.com
  only:
    - develop

deploy:staging:
  stage: deploy-staging
  script:
    - kubectl set image deployment/app app=$IMAGE_NAME:$CI_COMMIT_SHA -n staging
    - kubectl rollout status deployment/app -n staging
  environment:
    name: staging
    url: https://staging.example.com
  only:
    - main
  when: manual

deploy:prod:
  stage: deploy-prod
  script:
    - kubectl set image deployment/app app=$IMAGE_NAME:$CI_COMMIT_SHA -n production
    - kubectl rollout status deployment/app -n production
    - curl $PROD_URL/health  # Smoke test
  environment:
    name: production
    url: https://app.example.com
  only:
    - tags
  when: manual
```

---

## Version Control Strategy

### Git Workflow

```
main (production)
  ↑
  ├─ release/v1.0
  │   ↑
  ├─ develop (staging)
  │   ↑
  ├─ feature/new-feature (developers)
  │   ↑
  └─ hotfix/critical-bug (emergency)
```

### Branch Protection Rules

```yaml
---
# Branch protection configuration
main:
  required_status_checks:
    - build
    - test:unit
    - test:integration
    - security:sast
    - security:dast
  require_code_review: true
  required_approvals: 2
  dismiss_stale_reviews: false
  require_branches_up_to_date: true
  allow_force_pushes: false
  allow_deletions: false

develop:
  required_status_checks:
    - build
    - test:unit
    - test:integration
    - security:sast
  require_code_review: true
  required_approvals: 1
  dismiss_stale_reviews: true
  allow_force_pushes: false

feature/*:
  required_status_checks:
    - build
    - test:unit
  require_code_review: false
```

### Commit Message Convention

```
<type>(<scope>): <subject>

<body>

<footer>

# Type: feat, fix, docs, style, refactor, test, chore
# Scope: component, module affected
# Subject: imperative mood, no period
# Body: detailed explanation of changes
# Footer: BREAKING CHANGE, Closes #123
```

Example:
```
feat(auth): add oauth2 support

- Integrate Google OAuth2 provider
- Add user profile synchronization
- Add logout endpoint

Closes #456
BREAKING CHANGE: /login endpoint replaced with /oauth/login
```

---

## Build Process

### Docker Build Best Practices

```dockerfile
# Multi-stage build to reduce image size
FROM node:18-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Build application
COPY . .
RUN npm run build

# Runtime stage
FROM node:18-alpine

WORKDIR /app

# Non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy from builder
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./

# Install runtime dependencies only
RUN npm ci --only=production && \
    npm cache clean --force

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

USER nodejs

EXPOSE 3000

CMD ["node", "dist/index.js"]
```

### Build Optimization

```yaml
---
# Cache layers for faster builds
.build_template:
  image: docker:latest
  services:
    - docker:dind
  variables:
    DOCKER_DRIVER: overlay2
    DOCKER_TLS_CERTDIR: ""
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY

build:
  extends: .build_template
  script:
    # Pull cache from registry
    - docker pull $IMAGE_NAME:latest || true
    
    # Build with cache
    - docker build \
        --cache-from $IMAGE_NAME:latest \
        --tag $IMAGE_NAME:$CI_COMMIT_SHA \
        --tag $IMAGE_NAME:latest \
        .
    
    # Push tags
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA
    - docker push $IMAGE_NAME:latest
```

---

## Testing Strategy

### Unit Testing

```bash
# Coverage thresholds
npm run test:unit -- \
  --coverage \
  --coverageThreshold '{
    "global": {
      "branches": 80,
      "functions": 80,
      "lines": 80,
      "statements": 80
    }
  }'
```

### Integration Testing

```yaml
---
# Integration test pipeline
test:integration:
  stage: test
  services:
    - postgres:14
    - redis:7
  variables:
    POSTGRES_DB: test_db
    POSTGRES_USER: test_user
    POSTGRES_PASSWORD: test_pass
  script:
    - npm run test:integration
  coverage: '/Coverage: \d+\.\d+%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
```

### Smoke Testing

```bash
#!/bin/bash
# smoke-test.sh - Quick health checks

set -e

RETRY_COUNT=5
RETRY_DELAY=10

echo "Running smoke tests on $APP_URL"

# Check application is responding
for i in $(seq 1 $RETRY_COUNT); do
  if curl -f -s "$APP_URL/health" > /dev/null; then
    echo "✓ Health check passed"
    break
  fi
  
  if [ $i -lt $RETRY_COUNT ]; then
    echo "Health check attempt $i failed, retrying in ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
  else
    echo "✗ Health check failed after $RETRY_COUNT attempts"
    exit 1
  fi
done

# Check database connectivity
curl -f -s "$APP_URL/api/health/db" || exit 1
echo "✓ Database connectivity verified"

# Check critical endpoints
curl -f -s "$APP_URL/api/status" || exit 1
echo "✓ API endpoints responding"

echo "✓ All smoke tests passed"
```

### Load Testing

```yaml
---
# Load testing with k6
test:load:
  stage: test
  image: loadimpact/k6:latest
  script:
    - k6 run --vus 100 --duration 5m load-test.js
  artifacts:
    reports:
      performance: performance-results.json
  only:
    - main
  when: manual
```

---

## Artifact Management

### Enterprise Package Management - Artifact Store Requirements

**⚠️ CRITICAL IN ENTERPRISE ENVIRONMENTS:**

In enterprise setups, **all packages and dependencies MUST be pulled from an internal Artifact Store** (Nexus, Artifactory, Azure Artifacts, etc.). Direct downloads from internet sources are **NOT ALLOWED** for the following reasons:

✅ **Security Control** - No unauthorized external dependencies
✅ **Supply Chain Security** - Protection against package tampering
✅ **Network Compliance** - All traffic stays within corporate network
✅ **Version Control** - Single source of truth for all dependencies
✅ **Availability** - Guaranteed access during internet outages
✅ **License Compliance** - Scan and audit all packages centrally
✅ **Performance** - Faster local delivery vs internet latency

### Artifact Store Configuration

**Nexus/Artifactory Setup**

```yaml
---
# Configure CI/CD to use internal Artifact Store only
variables:
  NPM_REGISTRY: "https://nexus.company.com/repository/npm/"
  PIP_INDEX_URL: "https://nexus.company.com/repository/pypi/simple"
  DOCKER_REGISTRY: "https://nexus.company.com/repository/docker/"
  MAVEN_REPOSITORY: "https://nexus.company.com/repository/maven-public/"

build:npm:
  stage: build
  script:
    # Configure npm to use internal registry ONLY
    - echo '@registry.npmjs.org/:_authToken=' > .npmrc
    - echo 'registry=' >> .npmrc
    - cat >> .npmrc << EOF
registry=${NPM_REGISTRY}
@company:registry=${NPM_REGISTRY}
always-auth=true
EOF
    
    # Install from internal registry
    - npm ci --registry ${NPM_REGISTRY}
    
    # Build
    - npm run build
  artifacts:
    paths:
      - dist/

build:python:
  stage: build
  image: python:3.11
  script:
    # Configure pip to use internal repository
    - pip config set global.index-url ${PIP_INDEX_URL}
    - pip config set global.trusted-host nexus.company.com
    
    # Install dependencies from internal store
    - pip install -r requirements.txt
    
    # Build and upload to internal repository
    - python setup.py bdist_wheel
    - twine upload -r internal dist/*
  artifacts:
    paths:
      - dist/

build:docker:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    # Login to internal Docker registry
    - docker login -u ${ARTIFACTORY_USER} -p ${ARTIFACTORY_PASSWORD} ${DOCKER_REGISTRY}
    
    # Configure Docker to use internal mirror
    - |
      cat > /etc/docker/daemon.json << EOF
      {
        "registry-mirrors": ["https://nexus.company.com/repository/docker/"],
        "insecure-registries": ["nexus.company.com"]
      }
      EOF
    
    # Build and push to internal registry
    - docker build -t ${DOCKER_REGISTRY}app:${CI_COMMIT_SHA} .
    - docker push ${DOCKER_REGISTRY}app:${CI_COMMIT_SHA}
```

### Artifact Store Mirror Configuration

```yaml
---
# Nexus 3 - Public Repository Mirrors
repositories:
  npm-public:
    type: proxy
    format: npm
    remote_url: https://registry.npmjs.org
    description: "Mirror of npmjs.org"
  
  pypi-public:
    type: proxy
    format: pypi
    remote_url: https://pypi.org/simple
    description: "Mirror of PyPI"
  
  docker-public:
    type: proxy
    format: docker
    remote_url: https://registry-1.docker.io
    description: "Mirror of Docker Hub"
  
  maven-public:
    type: proxy
    format: maven2
    remote_url: https://repo1.maven.org/maven2
    description: "Mirror of Maven Central"

  # Group repositories combining internal + mirrors
  npm-all:
    type: group
    members:
      - npm-internal
      - npm-public
  
  docker-all:
    type: group
    members:
      - docker-internal
      - docker-public
```

### Verification: No Direct Internet Downloads

```yaml
---
# Strict policy - fail if direct internet access attempted
security:enforce-artifact-store:
  stage: build
  script:
    # Verify no direct npm downloads
    - |
      if grep -r "registry.npmjs.org" package-lock.json; then
        echo "ERROR: Direct npmjs.org registry detected in dependencies!"
        echo "All packages must come from internal Artifact Store"
        exit 1
      fi
    
    # Verify no direct PyPI downloads
    - |
      if grep -r "pypi.org\|files.pythonhosted.org" requirements.txt; then
        echo "ERROR: Direct PyPI access attempted!"
        echo "Use internal repository only"
        exit 1
      fi
    
    # Verify Docker images from internal registry
    - |
      if grep -E "FROM.*docker.io|FROM.*gcr.io|FROM.*public.ecr.aws" Dockerfile; then
        echo "ERROR: Docker image from public registry detected!"
        echo "All base images must be in internal registry"
        exit 1
      fi
    
    echo "✓ All packages verified to use internal Artifact Store"
```

### Container Registry

```yaml
---
# Push to multiple registries
build:
  stage: build
  script:
    # Docker Hub
    - docker login -u $DOCKER_HUB_USER -p $DOCKER_HUB_TOKEN
    - docker build -t $DOCKER_HUB_REPO:$CI_COMMIT_SHA .
    - docker push $DOCKER_HUB_REPO:$CI_COMMIT_SHA
    
    # AWS ECR
    - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ECR_REPO
    - docker tag $DOCKER_HUB_REPO:$CI_COMMIT_SHA $AWS_ECR_REPO:$CI_COMMIT_SHA
    - docker push $AWS_ECR_REPO:$CI_COMMIT_SHA
    
    # Private Registry
    - docker login -u $PRIVATE_REGISTRY_USER -p $PRIVATE_REGISTRY_TOKEN $PRIVATE_REGISTRY
    - docker tag $DOCKER_HUB_REPO:$CI_COMMIT_SHA $PRIVATE_REGISTRY/app:$CI_COMMIT_SHA
    - docker push $PRIVATE_REGISTRY/app:$CI_COMMIT_SHA
```

### Image Scanning

```yaml
---
# Scan for vulnerabilities
security:scan:
  stage: security
  image: aquasec/trivy:latest
  script:
    # Scan image
    - trivy image --exit-code 0 --severity HIGH,CRITICAL --format json $IMAGE_NAME:$CI_COMMIT_SHA > scan-results.json
    
    # Fail on critical vulnerabilities
    - trivy image --exit-code 1 --severity CRITICAL $IMAGE_NAME:$CI_COMMIT_SHA
  artifacts:
    reports:
      container_scanning: scan-results.json
  allow_failure: false
```

### Artifact Retention

```yaml
---
# Artifact lifecycle policy
artifacts:
  name: "build-$CI_COMMIT_SHA"
  paths:
    - dist/
    - coverage/
  reports:
    coverage_report:
      coverage_format: cobertura
      path: coverage/cobertura-coverage.xml
  expire_in: 30 days  # Automatically delete after 30 days
  
  # Keep artifacts only for certain conditions
  when: on_success
```

---

## Deployment Strategies

### Blue-Green Deployment

```yaml
---
deploy:prod:blue-green:
  stage: deploy-prod
  script:
    # Get current active deployment
    - ACTIVE=$(kubectl get service app-lb -o jsonpath='{.spec.selector.deployment}')
    - |
      if [ "$ACTIVE" == "blue" ]; then
        TARGET="green"
      else
        TARGET="blue"
      fi
    
    # Deploy to inactive
    - kubectl set image deployment/app-$TARGET app=$IMAGE_NAME:$CI_COMMIT_SHA
    - kubectl rollout status deployment/app-$TARGET --timeout=5m
    
    # Run smoke tests on TARGET
    - ./smoke-test.sh https://app-$TARGET.example.com
    
    # Switch traffic
    - kubectl patch service app-lb -p '{"spec":{"selector":{"deployment":"'$TARGET'"}}}'
    
    # Keep old deployment for quick rollback
    - echo "Blue-Green deployment complete. Active: $TARGET"
  environment:
    name: production
  only:
    - tags
  when: manual
```

### Canary Deployment

```yaml
---
deploy:prod:canary:
  stage: deploy-prod
  script:
    # Deploy canary with 10% traffic
    - kubectl set image deployment/app-canary app=$IMAGE_NAME:$CI_COMMIT_SHA
    - kubectl rollout status deployment/app-canary --timeout=5m
    
    # Monitor metrics for 5 minutes
    - |
      for i in {1..30}; do
        ERROR_RATE=$(curl -s http://prometheus:9090/query?query='rate(http_requests_total{status=~"5.."}[5m])' | jq '.data.result[0].value[1]' -r)
        if (( $(echo "$ERROR_RATE > 0.05" | bc -l) )); then
          echo "High error rate detected: $ERROR_RATE"
          kubectl rollout undo deployment/app-canary
          exit 1
        fi
        sleep 10
      done
    
    # Gradually increase traffic
    - kubectl patch virtualservice app --type merge -p '{"spec":{"hosts":[{"name":"app","http":[{"match":[{"uri":{"prefix":"/"}}],"route":[{"destination":{"host":"app-stable"},"weight":50},{"destination":{"host":"app-canary"},"weight":50}]}]}]}}'
    - sleep 300
    
    # Promote canary to stable if successful
    - kubectl set image deployment/app-stable app=$IMAGE_NAME:$CI_COMMIT_SHA
    - kubectl rollout status deployment/app-stable --timeout=5m
  environment:
    name: production
  only:
    - tags
  when: manual
```

### Rolling Deployment

```yaml
---
deploy:staging:rolling:
  stage: deploy-staging
  script:
    # Rolling update with Kubernetes
    - kubectl set image deployment/app app=$IMAGE_NAME:$CI_COMMIT_SHA
    - kubectl rollout status deployment/app --timeout=10m
    - ./smoke-test.sh https://staging.example.com
  environment:
    name: staging
  only:
    - main
  when: manual
```

---

## Environment Management

### Environment Configuration

```yaml
---
# Development environment
environments:
  dev:
    variables:
      APP_ENV: development
      LOG_LEVEL: debug
      DB_HOST: postgres-dev.internal
      CACHE_TTL: 60
      REPLICAS: 1
      RESOURCE_LIMIT: 256Mi
    
dev:build:
  variables: !reference [environments, dev, variables]
  script:
    - docker build -f Dockerfile.dev -t app:dev .

---
# Staging environment
  staging:
    variables:
      APP_ENV: staging
      LOG_LEVEL: info
      DB_HOST: postgres-staging.internal
      CACHE_TTL: 3600
      REPLICAS: 2
      RESOURCE_LIMIT: 512Mi

---
# Production environment
  prod:
    variables:
      APP_ENV: production
      LOG_LEVEL: warn
      DB_HOST: postgres-prod.internal
      CACHE_TTL: 86400
      REPLICAS: 5
      RESOURCE_LIMIT: 1Gi
```

### Secrets Management

```yaml
---
# Store secrets in CI/CD system
build:
  script:
    # Reference secrets from CI/CD
    - docker build \
        --build-arg DATABASE_URL=$DATABASE_URL \
        --build-arg API_KEY=$API_KEY \
        .
  secrets:
    DATABASE_URL:
      vault: $VAULT_ADDR/secret/data/prod/database
    API_KEY:
      vault: $VAULT_ADDR/secret/data/prod/api
```

---

## Pipeline as Code

### GitLab CI/CD Pipeline

```yaml
---
# .gitlab-ci.yml - Complete pipeline
variables:
  IMAGE_NAME: $CI_REGISTRY_IMAGE
  IMAGE_TAG: $CI_COMMIT_SHA
  DOCKER_DRIVER: overlay2

stages:
  - build
  - test
  - security
  - deploy
  - verify

before_script:
  - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY

build:image:
  stage: build
  script:
    - docker build -t $IMAGE_NAME:$IMAGE_TAG .
    - docker push $IMAGE_NAME:$IMAGE_TAG
  only:
    - branches
    - tags

test:unit:
  stage: test
  image: node:18
  script:
    - npm ci
    - npm run test:unit -- --coverage
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
    paths:
      - coverage/

test:integration:
  stage: test
  services:
    - postgres:14
    - redis:7
  script:
    - npm ci
    - npm run test:integration
  only:
    - develop
    - main

security:sast:
  stage: security
  image: returntocorp/semgrep:latest
  script:
    - semgrep --config p/security-audit --json -o semgrep-results.json .
  artifacts:
    reports:
      sast: semgrep-results.json
  allow_failure: true

deploy:dev:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl set image deployment/app app=$IMAGE_NAME:$IMAGE_TAG -n dev
    - kubectl rollout status deployment/app -n dev --timeout=10m
  environment:
    name: development
    url: https://dev.example.com
    kubernetes:
      namespace: dev
  only:
    - develop

deploy:prod:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl set image deployment/app app=$IMAGE_NAME:$IMAGE_TAG -n prod
    - kubectl rollout status deployment/app -n prod --timeout=10m
  environment:
    name: production
    url: https://app.example.com
    kubernetes:
      namespace: prod
    deployment_tier: production
  only:
    - tags
  when: manual

verify:smoke:
  stage: verify
  image: alpine:3.18
  script:
    - ./smoke-test.sh $ENVIRONMENT_URL
  only:
    - develop
    - main
    - tags
  when: on_success
```

### Jenkins Pipeline

```groovy
// Jenkinsfile - Jenkins pipeline as code
pipeline {
  agent any
  
  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
    
    stage('Build') {
      steps {
        sh 'docker build -t app:${BUILD_NUMBER} .'
      }
    }
    
    stage('Test') {
      parallel {
        stage('Unit Tests') {
          steps {
            sh 'npm run test:unit'
            junit 'test-results.xml'
          }
        }
        
        stage('SonarQube Scan') {
          steps {
            withSonarQubeEnv('SonarQube') {
              sh 'sonar-scanner'
            }
          }
        }
      }
    }
    
    stage('Deploy Dev') {
      when {
        branch 'develop'
      }
      steps {
        sh 'kubectl set image deployment/app app=app:${BUILD_NUMBER} -n dev'
      }
    }
    
    stage('Deploy Prod') {
      when {
        tag pattern: "v.*", comparator: "REGEXP"
      }
      input {
        message "Deploy to production?"
        ok "Deploy"
      }
      steps {
        sh 'kubectl set image deployment/app app=app:${BUILD_NUMBER} -n prod'
      }
    }
  }
  
  post {
    always {
      cleanWs()
    }
    failure {
      emailext(
        subject: 'Build Failed: ${JOB_NAME} #${BUILD_NUMBER}',
        body: '${BUILD_LOG_EXCERPT}',
        to: 'devops@example.com'
      )
    }
  }
}
```

---

## Security in CI/CD

### Secrets Scanning

```yaml
---
security:secrets:
  stage: security
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks detect --source . --report-path gitleaks-report.json
  artifacts:
    reports:
      secret_detection: gitleaks-report.json
  allow_failure: false
```

### SBOM (Software Bill of Materials)

```yaml
---
security:sbom:
  stage: security
  image: aquasec/trivy:latest
  script:
    # Generate SBOM in CycloneDX format
    - trivy image --format cyclonedx --output sbom.json $IMAGE_NAME:$CI_COMMIT_SHA
  artifacts:
    paths:
      - sbom.json
```

### Signed Commits

```bash
# Configure GPG signing
git config user.signingkey <GPG_KEY_ID>
git config commit.gpgsign true
git config gpg.program gpg2

# Commit with signature
git commit -m "feat: new feature" -S

# Verify signature
git verify-commit HEAD
```

---

## Monitoring and Observability

### Pipeline Metrics

```yaml
---
# Collect pipeline metrics
before_script:
  - START_TIME=$(date +%s)
  
after_script:
  - |
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    curl -X POST http://prometheus-pushgateway:9091/metrics/job/ci_pipeline \
      -d "pipeline_duration_seconds $DURATION"
```

### Test Coverage Tracking

```yaml
---
test:coverage:
  stage: test
  coverage: '/Coverage: (\d+.\d+)%/'
  script:
    - npm run test:coverage
  artifacts:
    paths:
      - coverage/
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
```

### Pipeline Status Dashboard

```bash
#!/bin/bash
# dashboard.sh - Simple pipeline status

GITLAB_URL="https://gitlab.example.com"
PROJECT_ID="123"
TOKEN="$CI_JOB_TOKEN"

# Get last 10 pipelines
curl -s -H "PRIVATE-TOKEN: $TOKEN" \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/pipelines?per_page=10" | \
  jq -r '.[] | "\(.id) \(.status) \(.updated_at)"'
```

---

## Scaling and Performance

### Parallel Job Execution

```yaml
---
test:
  parallel:
    matrix:
      - NODE_VERSION: [14, 16, 18]
        DB_VERSION: [11, 12, 13]
  image: node:$NODE_VERSION
  services:
    - postgres:$DB_VERSION
  script:
    - npm test
```

### Caching

```yaml
---
build:
  cache:
    key:
      files:
        - package-lock.json
      prefix: npm-cache
    paths:
      - node_modules/
  script:
    - npm ci
    - npm run build
```

### Resource Limits

```yaml
---
heavy:build:
  script:
    - docker build -t app:latest .
  tags:
    - high-memory
    - docker
  resource_group: $CI_COMMIT_REF_NAME  # Limit concurrent jobs per branch
```

---

## Disaster Recovery

### Backup Artifacts

```yaml
---
backup:artifacts:
  stage: deploy
  script:
    - |
      aws s3 cp \
        s3://ci-artifacts/app/latest.tar.gz \
        s3://ci-artifacts-backup/app/$(date +%Y%m%d_%H%M%S)_backup.tar.gz
  only:
    - cron
```

### Rollback Procedure

```bash
#!/bin/bash
# rollback.sh - Automated rollback

ENVIRONMENT=$1
PREVIOUS_VERSION=$(git describe --tags --abbrev=0 HEAD~1)

echo "Rolling back $ENVIRONMENT to $PREVIOUS_VERSION"

# Update deployment
kubectl set image deployment/app \
  app=$IMAGE_NAME:$PREVIOUS_VERSION \
  -n $ENVIRONMENT

# Wait for rollout
kubectl rollout status deployment/app -n $ENVIRONMENT --timeout=10m

# Verify
./smoke-test.sh $ENVIRONMENT

echo "Rollback complete"
```

---

## Troubleshooting Tips

| Issue | Cause | Solution |
|-------|-------|----------|
| Pipeline timeout | Long-running steps | Optimize tests, use parallel jobs |
| Flaky tests | Timing issues, external dependencies | Mock external services, add retries |
| Out of memory | Large builds or tests | Increase runner memory, split jobs |
| Registry auth fails | Expired credentials | Rotate registry credentials |
| Deployment fails | State drift, resource constraints | Check cluster resources, validate YAML |
| Artifact not found | Incorrect path or expiration | Check artifact retention settings |
| Secrets exposed | Logging output | Mask secrets in output |
| Build cache issues | Stale dependencies | Clear cache, rebuild from scratch |

---

## References and Resources

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/)
- [OWASP CI/CD Security](https://owasp.org/www-project-devsecops/)

---

**Version**: 1.0  
**Author**: Michael Vogeler  
**Last Updated**: December 1, 2025  
**Maintained By**: DevOps Team
