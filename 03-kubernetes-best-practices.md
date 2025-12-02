# Kubernetes Best Practices

A comprehensive guide for DevOps Engineers on implementing Kubernetes effectively and reliably at scale.

## Table of Contents

1. [Cluster Architecture](#cluster-architecture)
2. [Namespaces and RBAC](#namespaces-and-rbac)
3. [Pod Design and Deployment](#pod-design-and-deployment)
4. [Resource Management](#resource-management)
5. [Storage and Persistence](#storage-and-persistence)
6. [Networking](#networking)
7. [Configuration Management](#configuration-management)
8. [Secrets and Security](#secrets-and-security)
9. [Monitoring and Logging](#monitoring-and-logging)
10. [High Availability and Disaster Recovery](#high-availability-and-disaster-recovery)
11. [Performance Optimization](#performance-optimization)
12. [Security Hardening](#security-hardening)

---

## Cluster Architecture

### Recommended Cluster Setup

```yaml
# Multi-zone production cluster
Master Nodes (Control Plane):
  - 3 highly available masters across availability zones
  - Etcd backup strategy
  - API server load balancer
  
Worker Nodes:
  - Min 3 nodes for production
  - Node auto-scaling group
  - Resource allocation for workloads
  
Add-ons:
  - CNI plugin (Calico, Cilium, Weave)
  - Ingress controller
  - DNS (CoreDNS)
  - Metrics server
  - Persistent volume provisioner
```

### Cluster Initialization

```bash
# Initialize kubeadm cluster
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --kubernetes-version=v1.34.2

# Join worker nodes
kubeadm join 192.168.1.100:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:...

# Install CNI plugin
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

### High Availability Master

```yaml
---
# Stacked etcd topology (etcd on master nodes)
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  name: master-1
localAPIEndpoint:
  advertiseAddress: 10.0.1.10
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.34.2
controlPlaneEndpoint: api.example.com:6443
etcd:
  local:
    dataDir: /var/lib/etcd
networking:
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
```

---

## Namespaces and RBAC

### Multi-Tenancy with Namespaces

```yaml
---
# Create namespaces for environment isolation
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    tier: critical

---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
    tier: non-critical

---
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: development
    tier: non-critical

---
# Network policy for namespace isolation
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: production
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          environment: production
```

### RBAC Configuration

```yaml
---
# Service Account for application
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-account
  namespace: production

---
# Role with minimal permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: production
rules:
# Read pods
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
# Read configmaps
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]
# Read secrets (only specific)
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-secret"]
  verbs: ["get"]

---
# Bind role to service account
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-role-binding
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-role
subjects:
- kind: ServiceAccount
  name: app-account
  namespace: production

---
# ClusterRole for cross-namespace access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: metrics-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods"]
  verbs: ["get", "list"]

---
# ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metrics-reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: metrics-reader
subjects:
- kind: ServiceAccount
  name: monitoring-account
  namespace: monitoring
```

---

## Pod Design and Deployment

### Best Practice Pod Specification

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: production
  labels:
    app: myapp
    version: v1
    tier: backend
  annotations:
    description: "Production backend application"
spec:
  # Service account for security
  serviceAccountName: app-account
  
  # Security context
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  
  # DNS policy
  dnsPolicy: ClusterFirst
  
  # Container specification
  containers:
  - name: app
    image: myregistry.azurecr.io/myapp:v1.0.0
    imagePullPolicy: IfNotPresent
    
    # Ports
    ports:
    - name: http
      containerPort: 8080
      protocol: TCP
    - name: metrics
      containerPort: 9090
      protocol: TCP
    
    # Environment variables
    env:
    - name: LOG_LEVEL
      value: "info"
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: db-host
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: db-password
    
    # Resource requests and limits
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
    
    # Health checks
    livenessProbe:
      httpGet:
        path: /health/live
        port: http
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    
    readinessProbe:
      httpGet:
        path: /health/ready
        port: http
      initialDelaySeconds: 10
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 2
    
    # Startup probe for slow-starting applications
    startupProbe:
      httpGet:
        path: /health/startup
        port: http
      failureThreshold: 30
      periodSeconds: 10
    
    # Security context for container
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    
    # Volume mounts
    volumeMounts:
    - name: config
      mountPath: /etc/config
      readOnly: true
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/app
  
  # Init containers
  initContainers:
  - name: init-setup
    image: busybox:1.28
    command: ['sh', '-c', 'mkdir -p /var/cache/app && chmod 777 /var/cache/app']
    volumeMounts:
    - name: cache
      mountPath: /var/cache/app
  
  # Volumes
  volumes:
  - name: config
    configMap:
      name: app-config
      defaultMode: 0644
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir:
      sizeLimit: 1Gi
  
  # Tolerations for node taints
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "backend"
    effect: "NoSchedule"
  
  # Affinity rules
  affinity:
    # Pod anti-affinity for distribution
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - myapp
          topologyKey: kubernetes.io/hostname
    
    # Node affinity for resource type
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-type
            operator: In
            values:
            - compute-optimized
```

### Deployment with Rollout Strategy

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
  labels:
    app: myapp
spec:
  # Replica count
  replicas: 3
  
  # Rollout strategy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # One extra pod during rollout
      maxUnavailable: 0  # No downtime
  
  # Progress deadline
  progressDeadlineSeconds: 600
  
  # Revision history
  revisionHistoryLimit: 10
  
  # Selector
  selector:
    matchLabels:
      app: myapp
  
  # Template
  template:
    metadata:
      labels:
        app: myapp
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    
    spec:
      # Pod spec from above
      serviceAccountName: app-account
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      
      containers:
      - name: app
        image: myregistry.azurecr.io/myapp:v1.0.0
        # ... rest of container spec
```

### StatefulSet for Stateful Applications

```yaml
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: production
spec:
  serviceName: postgres-headless
  replicas: 3
  
  selector:
    matchLabels:
      app: postgres
  
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14-alpine
        ports:
        - containerPort: 5432
          name: postgres
        
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      
      # Ordinal pod identity
      terminationGracePeriodSeconds: 30
  
  # Persistent volume claim template
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 10Gi

---
# Headless Service for StatefulSet
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  namespace: production
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - port: 5432
    name: postgres
```

---

## Resource Management

### Resource Requests and Limits

```yaml
---
# Pod with resource requests
apiVersion: v1
kind: Pod
metadata:
  name: resource-aware
spec:
  containers:
  - name: app
    image: myapp:latest
    
    # Requests - what pod needs to start
    resources:
      requests:
        cpu: 100m           # 0.1 CPU core
        memory: 128Mi
        ephemeral-storage: 1Gi
      
      # Limits - maximum resources allowed
      limits:
        cpu: 500m           # 0.5 CPU cores
        memory: 512Mi
        ephemeral-storage: 2Gi
```

### ResourceQuota for Namespace

```yaml
---
# Limit resources per namespace
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    pods: "100"
    services: "10"
    persistentvolumeclaims: "5"
  
  # Scopes
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["high", "medium"]

---
# Limit individual pod resources
apiVersion: v1
kind: LimitRange
metadata:
  name: pod-limits
  namespace: production
spec:
  limits:
  # Per pod
  - type: Pod
    max:
      cpu: "1"
      memory: "1Gi"
    min:
      cpu: "10m"
      memory: "32Mi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
  
  # Per container
  - type: Container
    max:
      cpu: "1"
      memory: "1Gi"
    min:
      cpu: "10m"
      memory: "32Mi"
```

### PriorityClass

```yaml
---
# Define priority classes
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: critical
value: 1000
globalDefault: false
description: "Critical production workloads"

---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: normal
value: 100
globalDefault: true
description: "Normal workloads"

---
# Use priority class
apiVersion: v1
kind: Pod
metadata:
  name: critical-app
spec:
  priorityClassName: critical
  containers:
  - name: app
    image: myapp:latest
```

---

## Storage and Persistence

### Persistent Volume and Claim

```yaml
---
# Storage Class for different performance tiers
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer  # Delayed binding

---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
allowVolumeExpansion: true

---
# Persistent Volume Claim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: production
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 20Gi

---
# Pod using persistent volume
apiVersion: v1
kind: Pod
metadata:
  name: data-app
  namespace: production
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: data
      mountPath: /var/lib/app
  
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: app-data
```

### Data Backup Strategy

```yaml
---
# Snapshot for backup
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: app-data-backup
  namespace: production
spec:
  volumeSnapshotClassName: default
  source:
    persistentVolumeClaimName: app-data

---
# Restore from snapshot
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-restored
  namespace: production
spec:
  dataSource:
    name: app-data-backup
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

---

## Networking

### Service Types

```yaml
---
# ClusterIP - Internal only (default)
apiVersion: v1
kind: Service
metadata:
  name: app-internal
  namespace: production
spec:
  type: ClusterIP
  clusterIP: 10.96.0.100
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP

---
# NodePort - External access via node IP
apiVersion: v1
kind: Service
metadata:
  name: app-nodeport
  namespace: production
spec:
  type: NodePort
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080  # 30000-32767

---
# LoadBalancer - Cloud provider load balancer
apiVersion: v1
kind: Service
metadata:
  name: app-lb
  namespace: production
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
  loadBalancerIP: 203.0.113.100
  loadBalancerSourceRanges:
  - 203.0.113.0/24

---
# ExternalName - DNS alias
apiVersion: v1
kind: Service
metadata:
  name: external-db
  namespace: production
spec:
  type: ExternalName
  externalName: db.example.com
  port: 5432
```

### Ingress Configuration

```yaml
---
# Ingress with TLS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: production
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls-cert
  
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 3000

---
# Network Policy - control traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-netpol
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Ingress
  - Egress
  
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

---

## Configuration Management

### ConfigMap for Non-Sensitive Data

```yaml
---
# ConfigMap from file
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  app.properties: |
    server.port=8080
    server.servlet.context-path=/api
    logging.level=INFO
    
  database.properties: |
    db.host=postgres.production.svc.cluster.local
    db.port=5432
    db.pool.size=10

---
# ConfigMap from key-value pairs
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-config
  namespace: production
data:
  LOG_LEVEL: "info"
  API_TIMEOUT: "30000"
  FEATURE_FLAGS: |
    {
      "newUI": true,
      "betaFeatures": false
    }

---
# Pod using ConfigMap
apiVersion: v1
kind: Pod
metadata:
  name: app-with-config
spec:
  containers:
  - name: app
    image: myapp:latest
    
    # Mount as volume
    volumeMounts:
    - name: config
      mountPath: /etc/config
      readOnly: true
    
    # Inject as environment variables
    env:
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: env-config
          key: LOG_LEVEL
  
  volumes:
  - name: config
    configMap:
      name: app-config
      defaultMode: 0644
```

---

## Secrets and Security

### Secret Management

```yaml
---
# Create secret from literals
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: production
type: Opaque
stringData:
  database-password: "superSecretPassword123"
  api-key: "sk_live_xxx"

---
# TLS secret for HTTPS
apiVersion: v1
kind: Secret
metadata:
  name: app-tls
  namespace: production
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi... (base64 encoded)
  tls.key: LS0tLS1CRUdJTi... (base64 encoded)

---
# Docker registry secret
apiVersion: v1
kind: Secret
metadata:
  name: docker-credentials
  namespace: production
type: kubernetes.io/dockercfg
data:
  .dockercfg: eyJteXJlZ2lzdHJ5Lmf... (base64 encoded)

---
# Pod using secrets
apiVersion: v1
kind: Pod
metadata:
  name: secret-consumer
spec:
  imagePullSecrets:
  - name: docker-credentials
  
  containers:
  - name: app
    image: myregistry.azurecr.io/myapp:latest
    
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: database-password
    
    volumeMounts:
    - name: secrets
      mountPath: /run/secrets
      readOnly: true
  
  volumes:
  - name: secrets
    secret:
      secretName: app-secrets
      defaultMode: 0400
```

### Pod Security Standards

```yaml
---
# Enforce security standards at namespace level
apiVersion: v1
kind: Namespace
metadata:
  name: secure-workloads
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

---
# Pod Security Policy (deprecated, use standards)
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
  - ALL
  volumes:
  - 'configMap'
  - 'emptyDir'
  - 'projected'
  - 'secret'
  - 'downwardAPI'
  - 'persistentVolumeClaim'
  
  hostNetwork: false
  hostIPC: false
  hostPID: false
  
  runAsUser:
    rule: 'MustRunAsNonRoot'
  
  seLinux:
    rule: 'MustRunAs'
    seLinuxOptions:
      level: "s0:c123,c456"
  
  readOnlyRootFilesystem: true
```

---

## Monitoring and Logging

### Prometheus Metrics

```yaml
---
# Service monitor for Prometheus
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app-monitor
  namespace: production
spec:
  selector:
    matchLabels:
      monitoring: enabled
  
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics

---
# Pod with Prometheus annotations
apiVersion: v1
kind: Pod
metadata:
  name: monitored-app
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
spec:
  containers:
  - name: app
    image: myapp:latest
    ports:
    - name: metrics
      containerPort: 9090
```

### Structured Logging

```yaml
---
# Fluent Bit for log collection
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush        5
        Daemon       off
        Log_Level    info
    
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
    
    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    
    [OUTPUT]
        Name   elasticsearch
        Match  *
        Host   elasticsearch.logging.svc.cluster.local
        Port   9200
        Index  kubernetes-%Y.%m.%d

---
# DaemonSet for Fluent Bit
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: logging
spec:
  selector:
    matchLabels:
      name: fluent-bit
  
  template:
    metadata:
      labels:
        name: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:latest
        
        volumeMounts:
        - name: config
          mountPath: /fluent-bit/etc
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      
      volumes:
      - name: config
        configMap:
          name: fluent-bit-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
```

---

## High Availability and Disaster Recovery

### Horizontal Pod Autoscaler

```yaml
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  
  minReplicas: 3
  maxReplicas: 10
  
  metrics:
  # CPU-based scaling
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  
  # Memory-based scaling
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  
  # Custom metrics scaling
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 15
    
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

### Pod Disruption Budget

```yaml
---
# Ensure minimum availability during disruptions
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
  namespace: production
spec:
  minAvailable: 2  # At least 2 pods must stay up
  selector:
    matchLabels:
      app: myapp

---
# Alternative - max unavailable
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb-max
  namespace: production
spec:
  maxUnavailable: 1  # At most 1 pod can be down
  selector:
    matchLabels:
      app: myapp
```

### Backup and Restore

```bash
# Backup entire cluster
velero backup create cluster-backup-$(date +%s) --wait

# Backup specific namespace
velero backup create ns-backup-$(date +%s) \
  --include-namespaces production \
  --wait

# List backups
velero backup get

# Restore from backup
velero restore create --from-backup cluster-backup-1234567890

# Check restore status
velero restore describe cluster-backup-1234567890
```

---

## Performance Optimization

### Resource Optimization

```yaml
---
# Example: Right-sizing resources
apiVersion: v1
kind: Pod
metadata:
  name: optimized-app
spec:
  containers:
  - name: app
    image: myapp:latest
    
    resources:
      # Conservative requests for bin packing
      requests:
        cpu: 50m
        memory: 64Mi
      
      # Reasonable limits to prevent runaway
      limits:
        cpu: 200m
        memory: 256Mi

---
# Use init containers for setup (not running in main container)
apiVersion: v1
kind: Pod
metadata:
  name: with-init
spec:
  initContainers:
  - name: setup
    image: busybox
    command: ['sh', '-c', 'echo "Setup complete"']
  
  containers:
  - name: app
    image: myapp:latest
```

### Node Optimization

```bash
# Check node allocation
kubectl top nodes
kubectl top pods --all-namespaces

# Identify over-subscribed nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Drain node for maintenance
kubectl drain node-name --ignore-daemonsets --delete-emptydir-data

# Re-add drained node
kubectl uncordon node-name

# Permanently remove node
kubectl delete node node-name
```

---

## Security Hardening

### Network Policies

```yaml
---
# Deny all ingress by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
# Allow specific ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: myapp
  
  policyTypes:
  - Ingress
  
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
```

### RBAC Best Practices

```yaml
---
# Minimal permissions role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: minimal-role
  namespace: production
rules:
# Only what's needed
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]  # Only get, not list/create/delete

---
# Audit sensitive operations
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log pod exec
- level: RequestResponse
  verbs: ["exec"]
  resources:
  - group: ""
    resources: ["pods/exec"]
# Log secret access
- level: Metadata
  verbs: ["get", "list"]
  resources:
  - group: ""
    resources: ["secrets"]
# Log RBAC changes
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["*"]
```

---

## Troubleshooting Guide

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| Pod not starting | `kubectl describe pod` | Check resource limits, image availability, node capacity |
| CrashLoopBackOff | `kubectl logs pod-name` | Debug application errors, check health probes |
| ImagePullBackOff | `kubectl describe pod` | Verify image exists, credentials correct, registry access |
| Pending PVC | `kubectl describe pvc` | Check storage class, node available |
| Network unreachable | `kubectl exec -it pod -- curl service` | Check network policy, service endpoints |
| High CPU usage | `kubectl top pod` | Review resource limits, profile application |
| Storage full | `kubectl df node` | Expand volume or clean data |
| Evicted pods | `kubectl describe node` | Free up node resources |
| DNS resolution fails | `kubectl exec -it pod -- nslookup service` | Check CoreDNS, network policy |
| Persistent data lost | Check PVC/PV status | Verify storage class, backup retention |

---

## References and Resources

- [Official Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Kubernetes Security Guide](https://kubernetes.io/docs/concepts/security/)
- [Helm - Package Manager](https://helm.sh/)
- [Prometheus - Monitoring](https://prometheus.io/)
- [Velero - Backup and Restore](https://velero.io/)
- [Istio - Service Mesh](https://istio.io/)

---

**Version**: 1.0  
**Author**: Michael Vogeler  
**Last Updated**: December 1, 2025  
**Maintained By**: DevOps Team
