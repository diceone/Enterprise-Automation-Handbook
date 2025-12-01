# GitOps Best Practices

A comprehensive guide for DevOps Engineers on implementing GitOps principles for declarative infrastructure and application management.

## Table of Contents

1. [GitOps Principles](#gitops-principles)
2. [Repository Structure](#repository-structure)
3. [Declarative Configuration](#declarative-configuration)
4. [Version Control as Source of Truth](#version-control-as-source-of-truth)
5. [Automated Reconciliation](#automated-reconciliation)
6. [ArgoCD Implementation](#argocd-implementation)
7. [Flux Implementation](#flux-implementation)
8. [Multi-Environment Management](#multi-environment-management)
9. [Secrets Management in GitOps](#secrets-management-in-gitops)
10. [Security and Access Control](#security-and-access-control)
11. [Observability and Troubleshooting](#observability-and-troubleshooting)
12. [Best Practices and Patterns](#best-practices-and-patterns)

---

## GitOps Principles

### Core Principles

1. **Declarative System**: Infrastructure and applications described declaratively
2. **Version Control as Source of Truth**: Git as single source of truth
3. **Automated Synchronization**: System automatically converges to desired state
4. **Continuous Monitoring**: Continuous observation for drift detection
5. **Automated Remediation**: Automatic rollback on divergence

```
┌─────────────────────────────────────────────────────────┐
│                      Git Repository                      │
│  (Declarative Infrastructure & Application Configs)      │
└─────────────────────────────────────────────────────────┘
                         ↓
              GitOps Controller (ArgoCD/Flux)
                         ↓
     ┌────────────────────┴────────────────────┐
     ↓                                         ↓
  Continuous Pull                    Continuous Monitoring
  (Sync desired state)               (Detect drift)
     ↓                                         ↓
  Kubernetes Cluster ←────────────────────────┘
  (Current state)
```

---

## Repository Structure

### Recommended GitOps Repository Layout

```
gitops-infrastructure/
├── README.md
├── .gitignore
│
├── apps/                                    # Application deployments
│   ├── dev/
│   │   ├── app-one/
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── configmap.yaml
│   │   └── app-two/
│   │       ├── kustomization.yaml
│   │       └── deployment.yaml
│   ├── staging/
│   │   ├── app-one/
│   │   └── app-two/
│   └── prod/
│       ├── app-one/
│       └── app-two/
│
├── infrastructure/                         # Infrastructure components
│   ├── networking/
│   │   ├── vpc/
│   │   ├── ingress/
│   │   └── network-policies/
│   ├── storage/
│   │   ├── storage-classes/
│   │   └── persistent-volumes/
│   └── monitoring/
│       ├── prometheus/
│       ├── grafana/
│       └── alertmanager/
│
├── clusters/                               # Cluster configurations
│   ├── production/
│   │   ├── kustomization.yaml
│   │   └── cluster-config.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── cluster-config.yaml
│   └── development/
│       ├── kustomization.yaml
│       └── cluster-config.yaml
│
├── base/                                   # Base configurations (DRY)
│   ├── app-template/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── infrastructure-template/
│
├── overlays/                               # Environment-specific overrides
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
│
└── docs/
    ├── CONTRIBUTING.md
    ├── DEPLOYMENT.md
    └── TROUBLESHOOTING.md
```

---

## Declarative Configuration

### Kubernetes Manifests

```yaml
---
# apps/prod/app-one/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-one
  namespace: production
  labels:
    app: app-one
    version: v1
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: app-one
  template:
    metadata:
      labels:
        app: app-one
        version: v1
    spec:
      serviceAccountName: app-one
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
      - name: app
        image: myregistry.azurecr.io/app-one:v1.0.0
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 8080
        env:
        - name: ENVIRONMENT
          value: production
        - name: LOG_LEVEL
          value: info
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
---
# apps/prod/app-one/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: app-one
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: app-one
  ports:
  - name: http
    port: 80
    targetPort: http
```

### Kustomize for Configuration Management

```yaml
---
# base/app-template/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

namePrefix: app-

commonLabels:
  app: app-template
  managed-by: gitops

commonAnnotations:
  description: "Managed by GitOps"

replicas:
- name: deployment
  count: 1

images:
- name: app
  newName: myregistry.azurecr.io/app
  newTag: v1.0.0

resources:
- deployment.yaml
- service.yaml
- configmap.yaml

patchesStrategicMerge:
- patch-memory-limit.yaml

vars:
- name: ENVIRONMENT
  objref:
    kind: ConfigMap
    name: app-config
    apiVersion: v1
  fieldref:
    fieldpath: data.environment
```

```yaml
---
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

bases:
- ../../base/app-template

namePrefix: prod-

commonLabels:
  environment: production
  tier: critical

replicas:
- name: deployment
  count: 3

images:
- name: app
  newName: myregistry.azurecr.io/app
  newTag: v1.2.3  # Production version

resources:
- ingress.yaml
- pdb.yaml
- networkpolicy.yaml

patchesJson6902:
- target:
    group: apps
    version: v1
    kind: Deployment
    name: app-template
  patch: |-
    - op: replace
      path: /spec/template/spec/resources/limits/cpu
      value: "1"
    - op: replace
      path: /spec/template/spec/resources/limits/memory
      value: "1Gi"

secretGenerator:
- name: app-secrets
  envs:
  - secrets.env

configMapGenerator:
- name: app-config
  files:
  - config/app.properties
```

### Helm for Package Management

```yaml
---
# infrastructure/monitoring/prometheus-helm.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 1h
  url: https://prometheus-community.github.io/helm-charts

---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: prometheus
  namespace: monitoring
spec:
  interval: 1h
  chart:
    spec:
      chart: kube-prometheus-stack
      sourceRef:
        kind: HelmRepository
        name: prometheus-community
        namespace: flux-system
      version: "48.x"
  
  values:
    prometheus:
      prometheusSpec:
        retention: 30d
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 1000m
            memory: 4Gi
    
    grafana:
      enabled: true
      replicas: 2
      persistence:
        enabled: true
        size: 10Gi
    
    alertmanager:
      enabled: true
      config:
        route:
          group_by: ['alertname', 'cluster']
          group_wait: 10s
          group_interval: 10s
          repeat_interval: 12h
          receiver: 'null'
```

---

## Version Control as Source of Truth

### Single Source of Truth

```yaml
---
# clusters/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
# Infrastructure
- ../../infrastructure/networking/ingress
- ../../infrastructure/storage/storage-classes
- ../../infrastructure/monitoring

# Applications
- ../../apps/prod/app-one
- ../../apps/prod/app-two
- ../../apps/prod/app-three

# Namespaces
- namespaces.yaml

# RBAC
- rbac.yaml

# Network Policies
- network-policies.yaml
```

### GitOps Workflow

```bash
# 1. Developer makes changes to Git
git checkout -b feature/new-app
# Edit apps/dev/new-app/deployment.yaml
git add apps/dev/new-app/
git commit -m "feat: add new microservice"
git push origin feature/new-app

# 2. Create pull request
# PR automatically triggers CI checks

# 3. Review and merge (requires approval)
git checkout main
git merge feature/new-app

# 4. GitOps controller automatically reconciles
# ArgoCD/Flux detects change and applies to cluster

# 5. Verify deployment
kubectl get deployments -n development
```

---

## Automated Reconciliation

### ArgoCD Application

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-one-prod
  namespace: argocd
spec:
  # Project for RBAC
  project: production
  
  # Source configuration
  source:
    repoURL: https://github.com/company/gitops-infrastructure.git
    targetRevision: main
    path: overlays/prod/app-one
    
    # Kustomize configuration
    kustomize:
      version: v4.5.7
      images:
        - name: myregistry.azurecr.io/app-one
          newName: myregistry.azurecr.io/app-one
          newTag: v1.2.3
  
  # Destination cluster
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  
  # Sync policy
  syncPolicy:
    # Automated sync
    automated:
      prune: true           # Delete resources not in Git
      selfHeal: true        # Auto-sync on detected drift
      allow:
        empty: false
    
    # Sync options
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - RespectIgnoreDifferences=true
    
    # Retry policy
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  # Notification
  info:
  - name: Documentation
    value: https://docs.example.com/app-one
  
  # Ignore differences (optional)
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
```

### Flux GitRepository

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/company/gitops-infrastructure.git
  ref:
    branch: main
  
  # Authentication
  secretRef:
    name: git-credentials
  
  # Verification
  verification:
    mode: pgp
    secretRef:
      name: gpg-key

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: production
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: infrastructure
  
  path: ./clusters/production
  prune: true
  wait: true
  
  postBuild:
    substitute:
      environment: production
      cluster: prod-01
```

---

## ArgoCD Implementation

### ArgoCD Installation

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=available --timeout=600s \
  deployment/argocd-server -n argocd

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

### ArgoCD Application Management

```yaml
---
# Application with notifications
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-one
  namespace: argocd
  # Finalizer for deletion protection
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: production
  
  source:
    repoURL: https://github.com/company/gitops.git
    path: apps/prod/app-one
    targetRevision: main
    helm:
      version: v3
      releaseName: app-one
      values: |
        replicaCount: 3
        image:
          tag: v1.2.3
  
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5

---
# Notification
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack_token
  template.app-deployed: |
    message: Application {{.app.metadata.name}} deployed successfully
  trigger.on-sync-succeeded: |
    - when: app.status.operationState.finishedAt != ''
      oncePer: app.status.operationState.finishedAt
      send: [app-deployed]
```

---

## Flux Implementation

### Flux Installation

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Bootstrap Flux
flux bootstrap github \
  --owner=company \
  --repo=gitops-infrastructure \
  --path=clusters/production \
  --personal \
  --private=false
```

### Flux GitOps Workflow

```yaml
---
# clusters/production/flux-system/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- gotk-components.yaml
- gotk-sync.yaml

---
# clusters/production/apps.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps/production
  prune: true
  wait: true
  postBuild:
    substitute:
      environment: production
  dependsOn:
  - name: infrastructure

---
# Infrastructure first
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./infrastructure
  prune: true
  wait: true
```

---

## Multi-Environment Management

### Environment Promotion

```yaml
---
# Development → Staging → Production pipeline

# 1. Development automatically syncs with develop branch
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-dev
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/company/gitops.git
    targetRevision: develop
    path: overlays/dev/app-one
  destination:
    namespace: development
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

---
# 2. Staging requires manual promotion
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-staging
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/company/gitops.git
    targetRevision: staging
    path: overlays/staging/app-one
  destination:
    namespace: staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: false  # Manual promotion

---
# 3. Production with advanced controls
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-prod
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/company/gitops.git
    targetRevision: main
    path: overlays/prod/app-one
  destination:
    namespace: production
  syncPolicy:
    syncOptions:
    - RespectIgnoreDifferences=true
    retry:
      limit: 10
```

### Promotion Script

```bash
#!/bin/bash
# promote.sh - Promote app version across environments

APP=$1
VERSION=$2
ENVIRONMENTS=("dev" "staging" "prod")

for env in "${ENVIRONMENTS[@]}"; do
  echo "Promoting $APP to version $VERSION in $env"
  
  # Update image tag in kustomization.yaml
  cd "overlays/$env/$APP"
  kustomize edit set image \
    "myregistry.azurecr.io/$APP=myregistry.azurecr.io/$APP:$VERSION"
  
  # Create Git commit
  git add kustomization.yaml
  git commit -m "chore: promote $APP to v$VERSION in $env"
  
  # Wait for GitOps to sync
  sleep 30
  
  # Verify deployment
  kubectl rollout status deployment/$APP -n $env --timeout=5m
  
  cd -
done

git push origin main
echo "Promotion complete"
```

---

## Secrets Management in GitOps

### Sealed Secrets

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create secret and seal it
kubectl create secret generic app-secrets \
  --from-literal=db-password=secret123 \
  -o yaml | kubeseal -f - > sealed-secret.yaml

# Commit sealed secret to Git
git add sealed-secret.yaml
git commit -m "add sealed secrets"
```

```yaml
---
# sealed-secret.yaml (safe to commit)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: app-secrets
  namespace: production
spec:
  encryptedData:
    db-password: AgBvA3CzF...
  template:
    metadata:
      name: app-secrets
      namespace: production
    type: Opaque
```

### SOPS (Secrets Operations)

```bash
# Create encryption key
sops --version
export SOPS_AZURE_KEYVAULT_URI="https://keyvault.azure.com/keys/sops/..."

# Encrypt secrets file
sops --encrypt secrets.yaml > secrets.enc.yaml

# Decrypt for Flux
sops --decrypt secrets.enc.yaml > secrets.yaml
```

```yaml
---
# .sops.yaml - SOPS configuration
creation_rules:
  - path_regex: secrets\.yaml$
    azure_keyvault: 'https://keyvault.azure.com/keys/sops/...'
```

### Flux Image Automation

```yaml
---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageRepository
metadata:
  name: app-one
  namespace: flux-system
spec:
  image: myregistry.azurecr.io/app-one
  interval: 1m
  secretRef:
    name: registry-credentials

---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImagePolicy
metadata:
  name: app-one-latest
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: app-one
  policy:
    semver:
      range: '>=1.0.0 <2.0.0'

---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: app-one
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: gitops
  git:
    commit:
      author:
        email: flux@example.com
        name: Flux
      messageTemplate: 'chore: update app-one to {{.Images | join ", "}}'
  update:
    path: ./overlays/prod/app-one
    strategy: Setters
```

---

## Security and Access Control

### ArgoCD RBAC

```yaml
---
# ArgoCD RBAC policy
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: 'role:readonly'
  policy.csv: |
    # Roles
    p, admin, applications, *, */*, allow
    p, developer, applications, get, */*, allow
    p, developer, applications, sync, */*, allow
    p, viewer, applications, get, */*, allow
    p, deployer, applications, sync, prod-*, allow
    
    # Users
    g, admin-group, admin
    g, developer-group, developer
    g, deployer-group, deployer
    
    # Service accounts
    g, system:serviceaccount:ci:deployer, deployer
```

### Network Policies

```yaml
---
# Only allow traffic from ArgoCD
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-argocd
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: argocd
```

---

## Observability and Troubleshooting

### ArgoCD Monitoring

```yaml
---
# Monitor ArgoCD with Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/part-of: argocd
  endpoints:
  - port: metrics
    interval: 30s
```

### Troubleshooting

```bash
# Check ArgoCD Application status
argocd app get app-one

# Sync application manually
argocd app sync app-one

# View application logs
argocd app logs app-one

# Check diff between Git and cluster
argocd app diff app-one

# View Flux reconciliation status
flux get all -A

# View Kustomization details
flux get kustomization production

# Troubleshoot sync issues
kubectl describe application app-one -n argocd
kubectl logs -n argocd deployment/argocd-controller-manager
```

---

## Best Practices and Patterns

### Idempotency

```yaml
---
# All resources must be idempotent
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
  labels:
    app: app-one
    managed-by: gitops
data:
  app.properties: |
    # Idempotent configuration
    server.port=8080
    # No timestamps, no unique IDs
```

### Namespace Isolation

```yaml
---
# Separate namespaces for environments
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    pod-security.kubernetes.io/enforce: restricted

---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
```

### Testing GitOps Changes

```bash
# Test locally with kustomize
kustomize build overlays/prod > manifests.yaml
kubectl apply -f manifests.yaml --dry-run=client

# Validate manifests
kubeval manifests.yaml

# Test with kind cluster
kind create cluster
kubectl apply -f manifests.yaml
kind delete cluster
```

---

## References and Resources

- [GitOps Principles](https://opengitops.dev/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Helm Documentation](https://helm.sh/docs/)

---

**Version**: 1.0  
**Author**: Michael Vogeler  
**Last Updated**: December 1, 2025  
**Maintained By**: DevOps Team
