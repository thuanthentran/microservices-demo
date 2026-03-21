# Deployment Guide

Comprehensive guide for building, deploying, and releasing the Hipster Shop microservices to various environments.

## Table of Contents

1. [Build Process](#build-process)
2. [Deployment Strategies](#deployment-strategies)
3. [Environment Configuration](#environment-configuration)
4. [Container Registry](#container-registry)
5. [Kubernetes Deployment](#kubernetes-deployment)
6. [Release Workflow](#release-workflow)
7. [Monitoring & Validation](#monitoring--validation)
8. [Rollback Procedures](#rollback-procedures)

## Build Process

### Local Development Build

Each service builds independently:

```bash
# Go services
cd src/frontend
go build -o frontend

# Python services
cd src/emailservice
pip install -r requirements.txt
python email_server.py

# Node.js services
cd src/paymentservice
npm install
npm start

# C# services
cd src/cartservice
dotnet build
dotnet run

# Java services (Gradle)
cd src/adservice
./gradlew build
./gradlew installDist
```

### Docker Build

**Build all services**:
```bash
# Build all services at once
docker-compose build

# Build specific service
docker-compose build frontend

# Build without cache (fresh build)
docker-compose build --no-cache frontend
```

**Build arguments**:
```bash
# Build with custom base image
docker build --build-arg BASE_IMAGE=go:1.25-alpine \
    -t frontend:latest \
    -f src/frontend/Dockerfile \
    src/frontend/

# Build with build args
docker build --build-arg VERSION=1.0.0 \
    --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    -t frontend:1.0.0 .
```

### Multi-Stage Docker Builds

**Go Service Example**:
```dockerfile
# Stage 1: Build
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o frontend main.go

# Stage 2: Runtime
FROM alpine:latest
RUN apk --no-cache add ca-certificates
COPY --from=builder /app/frontend /app/frontend
EXPOSE 8080
CMD ["/app/frontend"]
```

**Python Service Example**:
```dockerfile
# Stage 1: Build dependencies
FROM python:3.11-slim as deps
WORKDIR /app
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim
WORKDIR /app
COPY --from=deps /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY . .
EXPOSE 50051
CMD ["python", "email_server.py"]
```

### Build Optimization

**Minimize image size**:
- Use alpine base images: ~5MB vs 300MB+
- Remove build dependencies in final stage
- Use .dockerignore to exclude unnecessary files

```dockerfile
# .dockerignore
.git
.gitignore
*.md
tests/
node_modules/
__pycache__/
.pytest_cache/
```

**Cache optimization**:
```dockerfile
# Put less-frequently changing items at top
FROM go:1.25-alpine
WORKDIR /app

# Copy go.mod/go.sum (changes less frequently)
COPY go.mod go.sum ./
RUN go mod download

# Copy source code (changes frequently)
COPY . .

# Build
RUN go build -o frontend
```

## Deployment Strategies

### Blue-Green Deployment

Maintain two identical production environments:

```yaml
# Blue environment (current)
apiVersion: apps/v1
kind: Deployment
metadata:
    name: frontend-blue
spec:
    replicas: 3
    selector:
        matchLabels:
            app: frontend
            version: blue

---
# Green environment (canary)
apiVersion: apps/v1
kind: Deployment
metadata:
    name: frontend-green
spec:
    replicas: 3
    selector:
        matchLabels:
            app: frontend
            version: green
```

**Switching traffic**:
```bash
# Route 100% to blue (current)
kubectl patch service frontend -p '{"spec":{"selector":{"version":"blue"}}}'

# Route 100% to green (new version)
kubectl patch service frontend -p '{"spec":{"selector":{"version":"green"}}}'
```

### Canary Deployment

Gradually roll out new version to subset of users:

```yaml
# Using Flagger for automated canary
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
    name: frontend
spec:
    targetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: frontend
    service:
        port: 8080
    analysis:
        interval: 1m
        threshold: 3
        metrics:
        - name: request-success-rate
          thresholdRange:
            min: 99
        - name: request-duration
          thresholdRange:
            max: 500
    webhooks:
        - name: test
          url: http://flagger-loadtester/
          timeout: 5s
          metadata:
            type: bash
            cmd: "curl http://frontend-canary:8080"
    skipAnalysis: false
```

### Rolling Update

Default Kubernetes strategy - gradually replace old pods:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: frontend
spec:
    replicas: 3
    strategy:
        type: RollingUpdate
        rollingUpdate:
            maxSurge: 1        # One extra pod during update
            maxUnavailable: 0  # Zero downtime
    selector:
        matchLabels:
            app: frontend
    template:
        metadata:
            labels:
                app: frontend
        spec:
            containers:
            - name: frontend
              image: frontend:1.0.0
              livenessProbe:
                  httpGet:
                      path: /health
                      port: 8080
                  initialDelaySeconds: 10
                  periodSeconds: 5
              readinessProbe:
                  httpGet:
                      path: /ready
                      port: 8080
                  initialDelaySeconds: 5
                  periodSeconds: 5
```

## Environment Configuration

### Environment Variables

**Development**:
```bash
# .env.dev
LOG_LEVEL=debug
DISABLE_TRACING=true
ENABLE_PROFILING=true
EXTRA_LATENCY=0
DATABASE_URL=localhost:5432
CACHE_ENABLED=false
```

**Staging**:
```bash
# .env.staging
LOG_LEVEL=info
DISABLE_TRACING=false
ENABLE_PROFILING=false
EXTRA_LATENCY=50
DATABASE_URL=staging-db.internal:5432
CACHE_ENABLED=true
CACHE_TTL=300
```

**Production**:
```bash
# .env.prod (managed by secrets)
LOG_LEVEL=warn
DISABLE_TRACING=false
ENABLE_PROFILING=false
EXTRA_LATENCY=0
DATABASE_URL=prod-db.internal:5432
CACHE_ENABLED=true
CACHE_TTL=3600
```

### Kubernetes ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
    name: app-config
    namespace: production
data:
    LOG_LEVEL: "info"
    DISABLE_TRACING: "false"
    CACHE_ENABLED: "true"
    CACHE_TTL: "3600"
---
apiVersion: v1
kind: Secret
metadata:
    name: app-secrets
    namespace: production
type: Opaque
data:
    DATABASE_PASSWORD: <base64-encoded-password>
    API_KEY: <base64-encoded-key>
    JWT_SECRET: <base64-encoded-secret>
```

**Mount in Deployment**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: frontend
spec:
    template:
        spec:
            containers:
            - name: frontend
              image: frontend:1.0.0
              envFrom:
              - configMapRef:
                  name: app-config
              - secretRef:
                  name: app-secrets
              env:
              - name: POD_NAME
                valueFrom:
                    fieldRef:
                        fieldPath: metadata.name
              - name: POD_NAMESPACE
                valueFrom:
                    fieldRef:
                        fieldPath: metadata.namespace
```

## Container Registry

### Docker Hub

```bash
# Login
docker login -u <username> -p <password>

# Tag image
docker tag frontend:latest myregistry/frontend:1.0.0
docker tag frontend:latest myregistry/frontend:latest

# Push
docker push myregistry/frontend:1.0.0
docker push myregistry/frontend:latest

# Pull from registry
docker pull myregistry/frontend:1.0.0

# Run from registry
docker run -it myregistry/frontend:1.0.0
```

### Google Container Registry (GCR)

```bash
# Configure authentication
gcloud auth configure-docker

# Tag image
docker tag frontend:latest gcr.io/PROJECT_ID/frontend:1.0.0

# Push
docker push gcr.io/PROJECT_ID/frontend:1.0.0

# View images
gcloud container images list

# View tags
gcloud container images list-tags gcr.io/PROJECT_ID/frontend
```

### Private Registry Authentication

```yaml
apiVersion: v1
kind: Secret
metadata:
    name: registry-secret
type: kubernetes.io/dockercfg
data:
    .dockercfg: |
        <base64-encoded-docker-config>

---
apiVersion: v1
kind: ServiceAccount
metadata:
    name: app
imagePullSecrets:
- name: registry-secret

---
apiVersion: apps/v1
kind: Deployment
metadata:
    name: frontend
spec:
    template:
        spec:
            serviceAccountName: app
            containers:
            - name: frontend
              image: private-registry.com/frontend:1.0.0
```

## Kubernetes Deployment

### Basic Deployment Manifest

```yaml
apiVersion: v1
kind: Namespace
metadata:
    name: production

---
apiVersion: apps/v1
kind: Deployment
metadata:
    name: frontend
    namespace: production
    labels:
        app: frontend
        version: 1.0.0
spec:
    replicas: 3
    selector:
        matchLabels:
            app: frontend
    minReadySeconds: 10
    revisionHistoryLimit: 5
    strategy:
        type: RollingUpdate
        rollingUpdate:
            maxSurge: 1
            maxUnavailable: 0
    template:
        metadata:
            labels:
                app: frontend
                version: 1.0.0
            annotations:
                prometheus.io/scrape: "true"
                prometheus.io/port: "8080"
                prometheus.io/path: "/metrics"
        spec:
            serviceAccountName: frontend
            containers:
            - name: frontend
              image: gcr.io/PROJECT_ID/frontend:1.0.0
              imagePullPolicy: Always
              ports:
              - containerPort: 8080
                name: http
              env:
              - name: LOG_LEVEL
                valueFrom:
                    configMapKeyRef:
                        name: app-config
                        key: LOG_LEVEL
              - name: DATABASE_PASSWORD
                valueFrom:
                    secretKeyRef:
                        name: app-secrets
                        key: database_password
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
                      port: 8080
                  initialDelaySeconds: 30
                  periodSeconds: 10
                  timeoutSeconds: 5
                  failureThreshold: 3
              readinessProbe:
                  httpGet:
                      path: /ready
                      port: 8080
                  initialDelaySeconds: 10
                  periodSeconds: 5
                  timeoutSeconds: 3
                  failureThreshold: 2
              volumeMounts:
              - name: config
                mountPath: /etc/config
                readOnly: true
            volumes:
            - name: config
              configMap:
                  name: app-config
            nodeSelector:
                disk: fast
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
                                - frontend
                          topologyKey: kubernetes.io/hostname

---
apiVersion: v1
kind: Service
metadata:
    name: frontend
    namespace: production
spec:
    type: LoadBalancer
    selector:
        app: frontend
    ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
      name: http
    sessionAffinity: ClientIP
```

### Deployment Commands

```bash
# Apply deployment
kubectl apply -f k8s/frontend.yaml

# Check deployment status
kubectl get deployments -n production
kubectl describe deployment frontend -n production

# Check pods
kubectl get pods -n production -l app=frontend
kubectl logs frontend-xxxxx -n production

# Scale deployment
kubectl scale deployment frontend --replicas=5 -n production

# Update image
kubectl set image deployment/frontend \
    frontend=gcr.io/PROJECT_ID/frontend:2.0.0 \
    -n production

# Check rollout status
kubectl rollout status deployment/frontend -n production

# View rollout history
kubectl rollout history deployment/frontend -n production

# Rollback to previous version
kubectl rollout undo deployment/frontend -n production
```

## Release Workflow

### Semantic Versioning

Version format: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes to API or architecture
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

Example: `1.2.3`
- 1: Major version
- 2: Minor version (new features since 1.0)
- 3: Patch version (bug fixes since 1.2.0)

### Release Checklist

```bash
#!/bin/bash
# release.sh - Automated release checklist

set -e

VERSION=$1  # e.g., "1.2.3"

# 1. Update version numbers
echo "Updating version to $VERSION..."
sed -i "s/version:.*/version: $VERSION/" helm/values.yaml
grep "version:" helm/values.yaml

# 2. Run tests
echo "Running tests..."
make test

# 3. Build Docker images
echo "Building images..."
docker-compose build

# 4. Tag images
echo "Tagging images..."
docker tag frontend:latest gcr.io/PROJECT_ID/frontend:$VERSION
docker tag frontend:latest gcr.io/PROJECT_ID/frontend:latest

# 5. Scan for vulnerabilities
echo "Scanning for vulnerabilities..."
trivy image gcr.io/PROJECT_ID/frontend:$VERSION

# 6. Push images
echo "Pushing images..."
docker push gcr.io/PROJECT_ID/frontend:$VERSION
docker push gcr.io/PROJECT_ID/frontend:latest

# 7. Update CHANGELOG
echo "Update CHANGELOG.md manually, then press Enter..."
read

# 8. Create git tag
echo "Tagging git..."
git tag -a "v${VERSION}" -m "Release version $VERSION"
git push origin "v${VERSION}"

echo "Release $VERSION complete!"
```

### Release Steps

1. **Prepare Release**
   - Update version numbers
   - Update CHANGELOG.md
   - Update README with new features

2. **Build & Test**
   - Run full test suite
   - Build Docker images
   - Security scanning

3. **Publish**
   - Push images to registry
   - Push git tags
   - Create GitHub release

4. **Deploy**
   - Deploy to staging
   - Run smoke tests
   - Deploy to production

## Monitoring & Validation

### Health Checks

Implement health check endpoints:

```go
// health.go
func healthHandler(w http.ResponseWriter, r *http.Request) {
    // Quick check - is service running?
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{
        "status": "ok",
        "version": "1.0.0",
    })
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
    // Deep check - can we serve traffic?
    
    // Check database connection
    if err := db.Ping(); err != nil {
        w.WriteHeader(http.StatusServiceUnavailable)
        json.NewEncoder(w).Encode(map[string]string{
            "status": "not ready",
            "reason": "database unavailable",
        })
        return
    }
    
    // Check dependencies
    if err := checkDependencies(); err != nil {
        w.WriteHeader(http.StatusServiceUnavailable)
        json.NewEncoder(w).Encode(map[string]string{
            "status": "not ready",
            "reason": "dependency unavailable",
        })
        return
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
}
```

### Smoke Tests

```bash
#!/bin/bash
# smoke_tests.sh - Basic functionality validation

FRONTEND_URL="http://frontend.production.svc.cluster.local:8080"

echo "Testing frontend..."
curl -f "$FRONTEND_URL/" || exit 1

echo "Testing product catalog..."
curl -f "$FRONTEND_URL/api/products" || exit 1

echo "Testing catalog search..."
curl -f "$FRONTEND_URL/api/products?q=test" || exit 1

echo "All smoke tests passed!"
```

### Metrics Validation

```bash
# Check key metrics
kubectl exec frontend-xxxxx -n production -- curl localhost:8080/metrics | grep -E "http_requests_total|http_request_duration"
```

## Rollback Procedures

### Kubernetes Rollback

```bash
# View rollout history
kubectl rollout history deployment/frontend -n production

# See details of specific revision
kubectl rollout history deployment/frontend -n production --revision=2

# Rollback to previous version
kubectl rollout undo deployment/frontend -n production

# Rollback to specific revision
kubectl rollout undo deployment/frontend -n production --to-revision=2

# Check rollback progress
kubectl rollout status deployment/frontend -n production
```

### Manual Rollback

```bash
# If Kubernetes rollback fails, use service selector
kubectl patch service frontend -n production \
    -p '{"spec":{"selector":{"version":"1.0.0"}}}'

# Or scale old deployment up, new one down
kubectl scale deployment frontend-v1 --replicas=3 -n production
kubectl scale deployment frontend-v2 --replicas=0 -n production
```

### Database Rollback

If schema changes are involved:

```bash
# Backup database before migration
kubectl exec -it postgresql-pod -- \
    pg_dump -U postgres mydb > backup-$(date +%s).sql

# Apply migration script
kubectl exec -it postgresql-pod -- \
    psql -U postgres mydb < migration.sql

# Restore from backup if needed
kubectl exec -it postgresql-pod -- \
    psql -U postgres mydb < backup-timestamp.sql
```

---

**Last Updated**: March 2026  
**Further Reading**: See [DEV_GUIDE.md](DEV_GUIDE.md) for local deployment
