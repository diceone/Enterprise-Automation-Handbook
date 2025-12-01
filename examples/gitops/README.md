# GitOps Examples

Complete GitOps implementations using ArgoCD and Flux for declarative infrastructure management.

## Files Overview

- `argocd-flux.yaml` - ArgoCD and Flux configurations
- `kustomization.md` - Kustomize structure examples
- Application manifests (in separate directories)

## ArgoCD Setup

### Prerequisites

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install ArgoCD CLI
brew install argocd
```

### Initial Configuration

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Login to ArgoCD
argocd login <ARGOCD_SERVER>

# Change password
argocd account update-password
```

### Connect Git Repository

```bash
# Add repository
argocd repo add https://github.com/myorg/myapp-config \
  --username <USERNAME> \
  --password <TOKEN>

# Verify repository
argocd repo list
```

### Deploy Application

```bash
# Apply ArgoCD Application
kubectl apply -f argocd-flux.yaml

# Monitor sync status
argocd app wait myapp-staging --sync

# View application
argocd app get myapp-staging

# Manual sync
argocd app sync myapp-staging
```

## Flux Setup

### Prerequisites

```bash
# Install Flux CLI
brew install fluxcd/tap/flux

# Bootstrap Flux
flux bootstrap github \
  --owner=myorg \
  --repository=myapp-config \
  --branch=main \
  --path=./clusters/production
```

### Deploy Applications

```bash
# Apply Flux manifests
kubectl apply -f argocd-flux.yaml

# Check reconciliation
flux get kustomizations

# Watch sync progress
flux get kustomizations --watch
```

## Repository Structure

```
myapp-config/
├── k8s/
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── kustomization.yaml
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── production/
│       ├── kustomization.yaml
│       └── patches/
├── helm/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   └── values-production.yaml
└── clusters/
    ├── dev/
    ├── staging/
    └── production/
```

## Key Concepts

### Declarative Configuration

All configuration is stored in Git. Kubernetes cluster state matches Git state.

```yaml
# Git repository source
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: myapp-config
spec:
  interval: 1m
  url: https://github.com/myorg/myapp-config
  ref:
    branch: main
```

### Automatic Reconciliation

```yaml
# Kustomization reconciles Git to cluster
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
spec:
  interval: 5m
  path: ./k8s/production
  prune: true  # Delete resources not in Git
  wait: true   # Wait for deployment ready
```

### Multi-Environment Management

```yaml
# ApplicationSet deploys to multiple environments
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-environments
spec:
  generators:
  - list:
      elements:
      - name: dev
      - name: staging
      - name: production
  template:
    spec:
      source:
        targetRevision: "{{ .name }}"
        path: "k8s/{{ .name }}"
```

## Common Workflows

### Deploy New Version

```bash
# 1. Update image tag in Git
git checkout -b update/app-v2

# 2. Update k8s/production/kustomization.yaml
# Change: newTag: v1.0.0 -> newTag: v2.0.0

# 3. Commit and push
git add .
git commit -m "chore: update app to v2.0.0"
git push origin update/app-v2

# 4. Create pull request
# 5. Merge to main
# 6. ArgoCD/Flux auto-syncs within 1-5 minutes
```

### Manual Approval for Production

```bash
# Configure manual sync for production
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-production
spec:
  syncPolicy: {} # No automatic sync
```

```bash
# Manually approve
argocd app sync myapp-production
```

### Rollback to Previous Version

```bash
# View revision history
argocd app history myapp-production

# Rollback to previous revision
argocd app rollback myapp-production 1
```

### Environmental Overrides

```bash
# Development - 1 replica, low resources
overlays/dev/kustomization.yaml
- replicas: 1
- cpu: 100m
- memory: 128Mi

# Staging - 2 replicas
overlays/staging/kustomization.yaml
- replicas: 2
- cpu: 250m
- memory: 512Mi

# Production - 3 replicas, high resources
overlays/production/kustomization.yaml
- replicas: 3
- cpu: 500m
- memory: 1Gi
```

## Monitoring & Notifications

### Slack Notifications

```yaml
# ArgoCD
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  service.slack: |
    token: $slack-token
  template.app-deployed: |
    message: "App {{.app.metadata.name}} deployed"
```

```yaml
# Flux
apiVersion: notification.toolkit.fluxcd.io/v1beta2
kind: Provider
metadata:
  name: slack
spec:
  type: slack
  address: https://hooks.slack.com/services/...
```

### Monitoring ArgoCD

```bash
# Check application status
kubectl get applications -n argocd

# View sync status
kubectl describe application myapp-production -n argocd

# Check errors
kubectl logs -n argocd deployment/argocd-server
```

### Monitoring Flux

```bash
# Check reconciliation status
flux get kustomizations

# View reconciliation details
flux describe kustomization myapp-production

# Check logs
flux logs --all-namespaces --follow
```

## Security Best Practices

✅ Use SSH for Git repository access
✅ Implement RBAC in ArgoCD
✅ Secret management with Sealed Secrets or SOPS
✅ Regular backup of configuration
✅ Audit logging enabled
✅ Network policies for ArgoCD/Flux pods
✅ Image scanning before deployment
✅ Admission webhooks for validation

## Troubleshooting

### Application Not Syncing

```bash
# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Check Git credentials
argocd repo list

# Manual sync
argocd app sync myapp-production
```

### Flux Reconciliation Failed

```bash
# Check Kustomization status
flux describe kustomization myapp-production

# View failed resources
flux get kustomizations --status failed

# Check controller logs
kubectl logs -n flux-system deployment/kustomize-controller
```

### Image Not Updated

```bash
# Check image policy
kubectl get imagepolicies

# Update manual scan
kubectl annotate imagepolicy myapp fluxcd.io/scan=now --overwrite
```

## Advanced Topics

### Custom Plugins

ArgoCD and Flux support custom tools:

```yaml
# Custom plugin for templating
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
spec:
  source:
    plugin:
      name: my-custom-plugin
```

### Multi-Cluster Management

```yaml
# Deploy across multiple clusters
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-multicluster
spec:
  generators:
  - clusterDecision:
      configMapRef: cluster-list
```

## References

- [GitOps Best Practices Guide](../05-gitops-best-practices.md)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
