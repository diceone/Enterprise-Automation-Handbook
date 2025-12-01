# Kustomization Base

## Overview

Base Kustomization structure for multi-environment deployments.

```
kustomization/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── production/
│       ├── kustomization.yaml
│       └── patches/
```

## Base Kustomization

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myapp

commonLabels:
  app: myapp
  managed-by: kustomize

commonAnnotations:
  team: platform

resources:
- deployment.yaml
- service.yaml
- configmap.yaml

images:
- name: myapp
  newTag: latest
```

## Development Overlay

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myapp-dev

bases:
- ../../base

replicas:
- name: myapp
  count: 1

patchesStrategicMerge:
- replicas-patch.yaml

configMapGenerator:
- name: app-config
  files:
  - config.properties
  behavior: merge
```

## Staging Overlay

```yaml
# overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myapp-staging

bases:
- ../../base

replicas:
- name: myapp
  count: 2

images:
- name: myapp
  newTag: staging-latest

patchesStrategicMerge:
- resources-patch.yaml
```

## Production Overlay

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myapp-production

bases:
- ../../base

replicas:
- name: myapp
  count: 3

images:
- name: myapp
  newTag: v1.0.0

patchesStrategicMerge:
- resources-patch.yaml
- hpa-patch.yaml

configMapGenerator:
- name: app-config
  literals:
  - environment=production
```

## Deploying with Kustomize

```bash
# Build base
kustomize build base

# Build dev overlay
kustomize build overlays/dev

# Deploy staging
kubectl apply -k overlays/staging

# Deploy production
kustomize build overlays/production | kubectl apply -f -
```
