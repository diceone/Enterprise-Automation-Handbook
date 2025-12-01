# Docker Best Practices

A comprehensive guide for building, managing, and deploying Docker containers with focus on security, performance, maintainability, and production readiness.

## Table of Contents

1. [Image Building](#image-building)
2. [Dockerfile Best Practices](#dockerfile-best-practices)
3. [Image Optimization](#image-optimization)
4. [Registry Management](#registry-management)
5. [Container Security](#container-security)
6. [Container Networking](#container-networking)
7. [Volume Management](#volume-management)
8. [Container Orchestration](#container-orchestration)
9. [Logging and Monitoring](#logging-and-monitoring)
10. [Performance Tuning](#performance-tuning)

---

## Image Building

### Build Context Optimization

**❌ BAD - Large, unoptimized build context:**
```dockerfile
# Dockerfile - includes unnecessary files
FROM ubuntu:22.04

COPY . /app/
WORKDIR /app

RUN apt-get update && \
    apt-get install -y build-essential && \
    npm install && \
    npm run build
```

**⚠️ Problem:** Build context includes `.git/`, `node_modules/`, test files, etc. This increases build time and image size.

**✅ GOOD - Optimized build context:**
```dockerfile
# .dockerignore
.git
.gitignore
node_modules
npm-debug.log
.env
.DS_Store
tests/
coverage/
docs/
README.md
LICENSE

# Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy only package files first
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY src ./src

# Build application
RUN npm run build

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Multi-Stage Builds

**❌ BAD - Single stage with build tools:**
```dockerfile
# Single stage - final image includes build tools
FROM golang:1.20

WORKDIR /app
COPY . .

RUN go build -o myapp .

ENTRYPOINT ["./myapp"]
```

**Result:** Image includes Go compiler, build tools (~2GB instead of ~50MB)

**✅ GOOD - Multi-stage build:**
```dockerfile
# Stage 1: Builder
FROM golang:1.20-alpine as builder

WORKDIR /app
COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o myapp .

# Stage 2: Runtime (minimal)
FROM alpine:3.18

# Add only runtime dependencies
RUN apk add --no-cache ca-certificates

WORKDIR /app

# Copy only the compiled binary
COPY --from=builder /app/myapp .

# Add non-root user
RUN adduser -D -u 1000 appuser
USER appuser

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["./myapp"]
```

**Result:** Image size reduced to ~50MB

---

## Dockerfile Best Practices

### Base Image Selection

**❌ BAD - Large base image:**
```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y python3
```

**Image size: ~77MB**

**✅ GOOD - Minimal base image:**
```dockerfile
FROM python:3.11-alpine

# Install only needed packages
RUN apk add --no-cache curl
```

**Image size: ~48MB (36% smaller)**

### Base Image Comparison

| Base Image | Size | Best For |
|-----------|------|----------|
| `alpine` | ~5MB | Minimal, security-focused |
| `debian:bookworm-slim` | ~69MB | Standard libs, moderate size |
| `ubuntu:22.04` | ~77MB | Desktop-like, larger footprint |
| `scratch` | 0MB | Statically compiled binaries only |
| `distroless` | ~10-50MB | Secure, minimal, language-specific |

### Layer Best Practices

**❌ BAD - Many layers, inefficient caching:**
```dockerfile
FROM ubuntu:22.04

RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git
RUN apt-get install -y build-essential
RUN apt-get install -y wget
RUN apt-get clean
```

**Result:** 6 layers, cache busts on any change

**✅ GOOD - Consolidated, optimized layers:**
```dockerfile
FROM ubuntu:22.04

# Combine RUN commands + cleanup
RUN apt-get update && \
    apt-get install -y \
      curl \
      git \
      build-essential \
      wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Application layers
COPY package*.json ./
RUN npm ci --only=production

COPY src ./src
```

### Ordering Layers for Cache Efficiency

**❌ BAD - Code changes invalidate all caches:**
```dockerfile
FROM node:18-alpine

COPY . /app/                    # ← Changes frequently
WORKDIR /app
RUN npm install                 # ← Cache invalidated
```

**✅ GOOD - Stable layers first:**
```dockerfile
FROM node:18-alpine

WORKDIR /app

# Layer 1: Package files (rarely changes)
COPY package*.json ./
RUN npm ci --only=production

# Layer 2: Application code (changes frequently)
COPY src ./src
RUN npm run build
```

**Result:** npm install cached until package.json changes

### User and Permissions

**❌ BAD - Running as root:**
```dockerfile
FROM ubuntu:22.04

COPY app.py /app/
CMD ["python3", "/app/app.py"]

# Runs as root!
```

**✅ GOOD - Non-root user:**
```dockerfile
FROM ubuntu:22.04

# Create non-root user
RUN useradd -m -u 1000 -s /sbin/nologin appuser

# Set working directory with proper ownership
WORKDIR /app
RUN chown -R appuser:appuser /app

COPY --chown=appuser:appuser app.py .

# Switch to non-root user
USER appuser

CMD ["python3", "app.py"]
```

### Health Checks

**❌ BAD - No health check:**
```dockerfile
FROM nginx:1.24-alpine

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY app /usr/share/nginx/html

CMD ["nginx", "-g", "daemon off;"]
# No way to detect if nginx is healthy
```

**✅ GOOD - Health check defined:**
```dockerfile
FROM nginx:1.24-alpine

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY app /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### Environment Variables

**❌ BAD - Sensitive data in ENV:**
```dockerfile
FROM python:3.11

ENV DATABASE_PASSWORD=secret123
ENV API_KEY=sk-1234567890
ENV DEBUG=true

COPY app.py /app/
CMD ["python3", "/app/app.py"]
```

**✅ GOOD - Configuration only, secrets from runtime:**
```dockerfile
FROM python:3.11

# Non-sensitive defaults only
ENV PYTHONUNBUFFERED=1
ENV LOG_LEVEL=info

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Secrets provided at runtime via:
# - Environment variables
# - Secret mounts
# - Configuration files
CMD ["python3", "app.py"]
```

---

## Image Optimization

### Reducing Image Size

**Size reduction techniques:**

1. **Use Alpine Linux**
   ```dockerfile
   FROM python:3.11-alpine
   ```

2. **Remove package manager cache**
   ```dockerfile
   RUN apt-get update && \
       apt-get install -y package && \
       apt-get clean && \
       rm -rf /var/lib/apt/lists/*
   ```

3. **Use multi-stage builds**
   ```dockerfile
   FROM builder as build
   RUN build-command
   
   FROM runtime
   COPY --from=build /build/output .
   ```

4. **Exclude unnecessary files**
   ```
   # .dockerignore
   .git
   .gitignore
   node_modules
   tests
   .env
   ```

5. **Use distroless images**
   ```dockerfile
   FROM gcr.io/distroless/python3
   COPY app.py .
   CMD ["app.py"]
   ```

### Size Comparison Example

```bash
# Before optimization
$ docker images app:old
REPOSITORY  TAG   IMAGE ID    SIZE
app         old   abc123      512MB

# After optimization
$ docker images app:new
REPOSITORY  TAG   IMAGE ID    SIZE
app         new   def456      45MB

# 91% size reduction!
```

### Build Optimization

```dockerfile
# Optimal Dockerfile structure
FROM alpine:3.18 as base

# Install base dependencies
RUN apk add --no-cache \
    ca-certificates \
    curl \
    && adduser -D -u 1000 appuser

# Builder stage
FROM base as builder

RUN apk add --no-cache build-base python3

WORKDIR /build
COPY . .
RUN pip install --user -r requirements.txt && \
    python3 setup.py build

# Runtime stage
FROM base

WORKDIR /app

# Copy only needed artifacts from builder
COPY --from=builder --chown=appuser:appuser /build/dist .
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

USER appuser

HEALTHCHECK --interval=30s --timeout=10s \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["python3", "-m", "app"]
```

---

## Registry Management

### Tagging Strategy

**❌ BAD - No clear versioning:**
```bash
docker build -t myapp .
docker push myregistry/myapp
# Latest? Version? Build date? Unknown!
```

**✅ GOOD - Semantic versioning + metadata:**
```bash
# Development builds
docker tag myapp:latest myregistry/myapp:dev-2025-01-15

# Release versions
docker tag myapp:v1.2.3 myregistry/myapp:v1.2.3
docker tag myapp:v1.2.3 myregistry/myapp:v1.2    # Minor version
docker tag myapp:v1.2.3 myregistry/myapp:v1      # Major version
docker tag myapp:v1.2.3 myregistry/myapp:latest  # Latest release

# Git commit hash (for traceability)
docker tag myapp:abc1234 myregistry/myapp:abc1234-stable

docker push myregistry/myapp --all-tags
```

### Registry Best Practices

**❌ BAD - Public registry, no organization:**
```bash
docker build -t myapp:latest .
docker push myapp:latest  # Pushes to Docker Hub public repo
```

**✅ GOOD - Private registry with organization:**
```bash
# Configure registry authentication
docker login myregistry.company.com

# Build and tag with registry
docker build -t myregistry.company.com/platform/myapp:v1.2.3 .

# Push to private registry
docker push myregistry.company.com/platform/myapp:v1.2.3

# Only pull from internal registry
docker pull myregistry.company.com/platform/myapp:v1.2.3
```

### Image Scanning in CI/CD

```yaml
# .gitlab-ci.yml
build:
  stage: build
  script:
    - docker build -t $REGISTRY/myapp:$CI_COMMIT_SHA .
    - docker push $REGISTRY/myapp:$CI_COMMIT_SHA

scan:
  stage: test
  script:
    # Scan with Trivy
    - trivy image --severity HIGH,CRITICAL $REGISTRY/myapp:$CI_COMMIT_SHA
    
    # Scan with Grype
    - grype $REGISTRY/myapp:$CI_COMMIT_SHA
    
    # Scan with Snyk
    - snyk container test $REGISTRY/myapp:$CI_COMMIT_SHA
  allow_failure: false

push:
  stage: deploy
  script:
    - docker push $REGISTRY/myapp:$CI_COMMIT_SHA
    - docker tag $REGISTRY/myapp:$CI_COMMIT_SHA $REGISTRY/myapp:latest
    - docker push $REGISTRY/myapp:latest
  only:
    - main
```

---

## Container Security

### Security Best Practices

**❌ BAD - Insecure container:**
```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y openssh-server

# Running as root, SSH enabled, no capabilities dropped
CMD ["/usr/sbin/sshd", "-D"]
```

**✅ GOOD - Secure container:**
```dockerfile
FROM ubuntu:22.04

# Install only needed packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /sbin/nologin appuser

WORKDIR /app
COPY --chown=appuser:appuser app.py .

# Drop unnecessary capabilities
RUN setcap -r /usr/bin/ping 2>/dev/null || true

USER appuser

# No SSH, minimal attack surface
CMD ["python3", "app.py"]
```

### Docker Security Options

```bash
# Run container with security constraints
docker run \
  --read-only \                              # Read-only filesystem
  --cap-drop=ALL \                           # Drop all capabilities
  --security-opt=no-new-privileges \         # No privilege escalation
  --security-opt=seccomp=default \           # Seccomp profile
  -u 1000 \                                  # Non-root user
  --memory=512m \                            # Memory limit
  --cpus=1 \                                 # CPU limit
  myregistry/myapp:latest
```

### Docker Compose Security

```yaml
# docker-compose.yml
version: '3.9'

services:
  app:
    image: myregistry/myapp:v1.2.3
    
    # Security options
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    
    # Read-only filesystem
    read_only: true
    
    # User
    user: "1000:1000"
    
    # Environment (no secrets)
    environment:
      LOG_LEVEL: info
      PORT: 8000
    
    # Secrets from secure storage
    secrets:
      - db_password
      - api_key
    
    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
    
    # Logging
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

secrets:
  db_password:
    file: ./secrets/db_password
  api_key:
    file: ./secrets/api_key
```

---

## Container Networking

### Network Best Practices

**❌ BAD - All containers on default bridge network:**
```yaml
# docker-compose.yml
services:
  app:
    image: myapp:latest
    ports:
      - "8000:8000"  # Exposed to host
  
  db:
    image: postgres:15
    ports:
      - "5432:5432"  # Exposed to host, no auth
```

**✅ GOOD - Isolated networks with proper access:**
```yaml
version: '3.9'

services:
  app:
    image: myregistry/myapp:latest
    networks:
      - frontend
      - backend
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgres://user:password@db:5432/app
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:15-alpine
    networks:
      - backend
    environment:
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser"]
      interval: 10s
      timeout: 5s
      retries: 5

  nginx:
    image: nginx:1.24-alpine
    networks:
      - frontend
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access

volumes:
  db_data:
    driver: local

secrets:
  db_password:
    file: ./secrets/db_password
```

---

## Volume Management

### Volume Best Practices

**❌ BAD - Anonymous volumes, no cleanup:**
```bash
docker run -v /data myapp:latest
docker run -v /data myapp:latest
docker run -v /data myapp:latest

# Creates orphaned volumes
docker volume ls
# Many unnamed volumes taking up space
```

**✅ GOOD - Named volumes with management:**
```bash
# Create named volume
docker volume create --driver local app_data

# Use named volume
docker run -v app_data:/data myapp:latest

# Clean up volumes
docker volume prune  # Remove unused volumes
docker volume rm app_data  # Remove specific volume

# Docker Compose with named volumes
cat > docker-compose.yml <<EOF
version: '3.9'

services:
  app:
    image: myapp:latest
    volumes:
      - app_data:/app/data
      - ./config:/app/config:ro

volumes:
  app_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /data/app
EOF
```

### Bind Mounts vs Volumes

| Feature | Bind Mount | Named Volume |
|---------|-----------|--------------|
| **Source** | Host filesystem | Docker managed |
| **Performance** | Slower (especially on Mac/Windows) | Faster |
| **Backup** | Manual | Docker managed |
| **Permissions** | Host permissions | Container permissions |
| **Use Case** | Development, config files | Production data, databases |

**✅ GOOD - Development setup:**
```bash
# Bind mount for live code editing
docker run \
  -v $(pwd)/src:/app/src \          # Bind mount for development
  -v app_data:/app/data \           # Named volume for data
  myapp:dev
```

---

## Container Orchestration

### Kubernetes Deployment Best Practices

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      # Pod disruption budget
      affinity:
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

      containers:
        - name: myapp
          image: myregistry/myapp:v1.2.3
          imagePullPolicy: IfNotPresent
          
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
              path: /health
              port: 8000
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          
          readinessProbe:
            httpGet:
              path: /ready
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 2
          
          # Security context
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          
          # Environment and secrets
          env:
            - name: LOG_LEVEL
              value: info
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: database_url
          
          # Volumes
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/cache
      
      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir:
            sizeLimit: 100Mi

      # Pod security policy
      securityContext:
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
```

---

## Logging and Monitoring

### Container Logging

**❌ BAD - Application logging to file:**
```dockerfile
FROM node:18-alpine

COPY app.js .

# Logs written to file - invisible to Docker
CMD ["node", "app.js"]
# app.js writes to app.log
```

**✅ GOOD - Logging to stdout/stderr:**
```dockerfile
FROM node:18-alpine

COPY app.js .

# Logs to stdout - visible to Docker logging drivers
CMD ["node", "app.js"]
# app.js logs to console.log (stdout)
```

**Docker Compose logging configuration:**
```yaml
services:
  app:
    image: myapp:latest
    
    logging:
      driver: "json-file"
      options:
        max-size: "10m"      # Max file size
        max-file: "3"        # Max number of files
        labels: "service=app"  # Add labels
    
    labels:
      - "service=app"
      - "version=v1.2.3"
```

### Monitoring Best Practices

```dockerfile
FROM node:18-alpine

# Install monitoring tools
RUN npm install prom-client

COPY app.js .
COPY health-check.js .

# Prometheus metrics endpoint
EXPOSE 8000 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
    CMD node health-check.js

CMD ["node", "app.js"]
```

**Prometheus metrics in application:**
```javascript
// app.js
const prometheus = require('prom-client');

const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_ms',
  help: 'Duration of HTTP requests in ms',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 5, 15, 50, 100, 500]
});

app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration);
  });
  next();
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(await prometheus.register.metrics());
});
```

---

## Performance Tuning

### Resource Limits and Requests

```yaml
# docker-compose.yml
services:
  app:
    image: myapp:latest
    
    deploy:
      resources:
        # What container needs to start
        requests:
          cpus: '0.5'
          memory: 256M
        
        # Maximum it can use
        limits:
          cpus: '2'
          memory: 1G
```

### Build Performance

```dockerfile
# Use BuildKit for faster builds
# DOCKER_BUILDKIT=1 docker build -t myapp .

# Leverage layer caching
FROM node:18-alpine

WORKDIR /app

# Layer 1: Dependencies (cached until package*.json changes)
COPY package*.json ./
RUN npm ci --only=production

# Layer 2: Source code (changes frequently)
COPY src ./src

# Layer 3: Build (only if source changes)
RUN npm run build

CMD ["npm", "start"]
```

### Network Performance

```yaml
# docker-compose.yml
services:
  app:
    image: myapp:latest
    network_mode: host  # Use host network for maximum performance
    # Warning: reduces network isolation
    
  # Better approach: use specific networks
  web:
    image: nginx:latest
    networks:
      - frontend
    
  api:
    image: myapi:latest
    networks:
      - frontend
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
```

---

## Docker Best Practices Checklist

### Before Building
- [ ] Clear .dockerignore configured
- [ ] Multi-stage build planned if needed
- [ ] Base image selected (minimal, updated)
- [ ] Security considerations addressed

### Building
- [ ] Layers ordered for cache efficiency
- [ ] RUN commands combined and cleaned
- [ ] Non-root user created
- [ ] Health check defined

### After Building
- [ ] Image scanned for vulnerabilities
- [ ] Image tested locally
- [ ] Image size acceptable
- [ ] Tags follow versioning strategy

### Registry Management
- [ ] Image pushed to internal registry
- [ ] Multiple tags applied (version, latest, etc.)
- [ ] Old images cleaned up
- [ ] Access controls configured

### Running Containers
- [ ] Security options applied
- [ ] Resource limits set
- [ ] Health checks enabled
- [ ] Logging configured
- [ ] Monitoring enabled

### Production
- [ ] Orchestration platform used (Kubernetes, Swarm)
- [ ] High availability configured
- [ ] Backup and recovery tested
- [ ] Incident response procedures in place

---

## References

- [Docker Official Documentation](https://docs.docker.com/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Security Best Practices](https://docs.docker.com/engine/security/)
- [Docker Container Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Google Container Best Practices](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke)
- [Container Standards](https://opencontainers.org/)

---

**Author**: Michael Vogeler  
**Last Updated**: December 2025  
**Maintained By**: DevOps Team
