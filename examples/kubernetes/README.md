# Kubernetes Examples

Production-ready Kubernetes manifests for application deployment.

## Quick Start

### 1. Create Namespace

```bash
kubectl create namespace myapp
```

### 2. Deploy Application

```bash
# Dry-run to validate
kubectl apply -f deployment.yaml --dry-run=client

# Apply manifests
kubectl apply -f deployment.yaml

# Verify deployment
kubectl rollout status deployment/myapp
```

### 3. Access Application

```bash
# Port forward to test locally
kubectl port-forward service/myapp 8080:80

# View logs
kubectl logs deployment/myapp -f

# Exec into pod
kubectl exec -it deployment/myapp -- /bin/sh
```

## File Structure

- `deployment.yaml` - Complete deployment with all best practices
- `namespaces.yaml` - Namespace definitions
- `rbac.yaml` - RBAC configurations
- `storage.yaml` - Persistent volumes

## Key Features

✅ Rolling update strategy
✅ Health probes (liveness, readiness)
✅ Resource requests and limits
✅ Security context
✅ Pod disruption budgets
✅ Horizontal pod autoscaling
✅ Network policies
✅ RBAC configuration
✅ Service monitoring annotations

## Useful Commands

### Check Deployment Status

```bash
# Get deployment info
kubectl get deployment myapp

# Describe deployment
kubectl describe deployment myapp

# Get pods
kubectl get pods -l app=myapp

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Monitor Resources

```bash
# Top resources
kubectl top nodes
kubectl top pods

# Watch deployment
kubectl get deployment -w
```

### Debugging

```bash
# Get logs
kubectl logs deployment/myapp
kubectl logs deployment/myapp --previous

# Describe pod
kubectl describe pod <POD_NAME>

# Check events
kubectl describe deployment myapp
```

### Scaling

```bash
# Manual scale
kubectl scale deployment myapp --replicas=5

# Check HPA status
kubectl get hpa myapp

# View HPA details
kubectl describe hpa myapp
```

### Rollback

```bash
# Rollout history
kubectl rollout history deployment/myapp

# Rollback to previous version
kubectl rollout undo deployment/myapp

# Rollback to specific revision
kubectl rollout undo deployment/myapp --to-revision=2
```

## Security Best Practices

- ✅ Non-root user (runAsUser: 1000)
- ✅ Read-only filesystem
- ✅ Dropped capabilities
- ✅ No privilege escalation
- ✅ Network policies
- ✅ RBAC configuration
- ✅ Secret management

## Monitoring

### Prometheus Metrics

```bash
# Access metrics
kubectl port-forward deployment/myapp 9090:9090
# Visit http://localhost:9090
```

### View Annotations

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"
```

## Troubleshooting

### Deployment Not Scaling

```bash
# Check HPA status
kubectl describe hpa myapp

# Check metrics
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1
```

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod <POD_NAME>

# Check container logs
kubectl logs <POD_NAME>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Network Issues

```bash
# Test connectivity from pod
kubectl exec -it <POD_NAME> -- curl localhost:8080

# Check network policy
kubectl get networkpolicy

# Check DNS
kubectl exec -it <POD_NAME> -- nslookup kubernetes.default
```

## References

- [Kubernetes Best Practices](../03-kubernetes-best-practices.md)
- [Official Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
