# CI/CD Pipeline Diagram

## Complete CI/CD Flow

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │    │   GitHub Repo    │    │  GitHub Actions │
│                 │───▶│                  │───▶│                 │
│ git push main   │    │  Source Code     │    │   CI/CD Runner  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                       ┌─────────────────────────────────────────────┐
                       │             BUILD STAGE                     │
                       │                                             │
                       │  ┌─────────────┐  ┌─────────────────────┐   │
                       │  │   Docker    │  │    Security Scan    │   │
                       │  │   Build     │  │     (Trivy)         │   │
                       │  │             │  │                     │   │
                       │  └─────────────┘  └─────────────────────┘   │
                       │          │                    │             │
                       │          ▼                    ▼             │
                       │  ┌─────────────┐  ┌─────────────────────┐   │
                       │  │   Push to   │  │   Quality Gates     │   │
                       │  │     GCR     │  │    (Pass/Fail)      │   │
                       │  │             │  │                     │   │
                       │  └─────────────┘  └─────────────────────┘   │
                       └─────────────────────────────────────────────┘
                                                │
                                                ▼
                       ┌─────────────────────────────────────────────┐
                       │            DEPLOY STAGE                     │
                       │                                             │
                       │ ┌─────────────────┐ ┌─────────────────────┐ │
                       │ │ Deploy Primary  │ │ Deploy Secondary    │ │
                       │ │  (us-central1)  │ │  (europe-west1)     │ │
                       │ │                 │ │                     │ │
                       │ └─────────────────┘ └─────────────────────┘ │
                       │          │                    │             │
                       │          ▼                    ▼             │
                       │ ┌─────────────────┐ ┌─────────────────────┐ │
                       │ │  Health Check   │ │   Health Check      │ │
                       │ │   Validation    │ │    Validation       │ │
                       │ │                 │ │                     │ │
                       │ └─────────────────┘ └─────────────────────┘ │
                       └─────────────────────────────────────────────┘
                                                │
                                                ▼
                       ┌─────────────────────────────────────────────┐
                       │           CANARY STAGE                      │
                       │                                             │
                       │ ┌─────────────────┐ ┌─────────────────────┐ │
                       │ │ Deploy Canary   │ │   Monitor Metrics   │ │
                       │ │   (10% traffic) │ │  Error Rate < 1%    │ │
                       │ │                 │ │  Latency < 100ms    │ │
                       │ └─────────────────┘ └─────────────────────┘ │
                       │          │                    │             │
                       │          ▼                    ▼             │
                       │ ┌─────────────────┐ ┌─────────────────────┐ │
                       │ │   Success?      │ │    Automatic        │ │
                       │ │ Promote to 100% │ │    Rollback         │ │
                       │ │                 │ │   (if failure)      │ │
                       │ └─────────────────┘ └─────────────────────┘ │
                       └─────────────────────────────────────────────┘
                                                │
                                                ▼
                       ┌─────────────────────────────────────────────┐
                       │            PRODUCTION                       │
                       │                                             │
                       │    ┌─────────────────────────────────────┐  │
                       │    │       Global Load Balancer          │  │
                       │    │                                     │  │
                       │    │  ┌─────────────┐ ┌───────────────┐  │  │
                       │    │  │us-central1  │ │ europe-west1  │  │  │
                       │    │  │             │ │               │  │  │
                       │    │  │ App v2.1    │ │  App v2.1     │  │  │
                       │    │  │ (HTTPS:443) │ │  (HTTPS:443)  │  │  │
                       │    │  └─────────────┘ └───────────────┘  │  │
                       │    └─────────────────────────────────────┘  │
                       └─────────────────────────────────────────────┘
```

## Detailed Pipeline Stages

### 1. Build Stage
**Trigger**: Git push to main branch
**Duration**: ~3-5 minutes

```yaml
Steps:
1. Checkout source code
2. Setup Google Cloud CLI
3. Configure Docker for GCR
4. Build Docker image with tags:
   - gcr.io/PROJECT/golang-ha:COMMIT_SHA
   - gcr.io/PROJECT/golang-ha:latest
5. Run security scan (Trivy)
6. Push to Google Container Registry
```

### 2. Deploy Stage  
**Duration**: ~5-7 minutes
**Strategy**: Blue-Green deployment

```yaml
Primary Deployment:
1. Get GKE credentials (us-central1)
2. Update deployment image tag
3. Wait for rollout completion (5min timeout)
4. Run health checks (/health endpoint)
5. Validate readiness probes

Secondary Deployment:
1. Get GKE credentials (europe-west1) 
2. Update deployment image tag
3. Wait for rollout completion (5min timeout)
4. Run health checks (/health endpoint)
5. Validate readiness probes
```

### 3. Canary Stage
**Duration**: ~5 minutes monitoring
**Traffic Split**: 10% canary, 90% stable

```yaml
Canary Process:
1. Deploy canary to golang-app-privileged namespace
2. Configure traffic split (Istio VirtualService)
3. Monitor metrics for 5 minutes:
   - Error rate < 1%
   - P95 latency < 100ms
   - Success rate > 99%
4. Decision:
   - Success: Promote canary to 100%
   - Failure: Automatic rollback

Rollback Triggers:
- Error rate > 1% for 2+ minutes
- P95 latency > 500ms for 2+ minutes  
- Health check failures > 3
```

## Container Strategy

### Multi-Stage Docker Build
```dockerfile
# Stage 1: Build
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Stage 2: Runtime
FROM alpine:3.18
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
USER 65534:65534
EXPOSE 8080
CMD ["./main"]
```

### Image Security
- **Base image**: Alpine Linux (minimal attack surface)
- **Non-root user**: UID 65534 (nobody)
- **No package manager**: Distroless approach
- **Security scanning**: Trivy checks for vulnerabilities
- **Image signing**: cosign signatures (future enhancement)

## HTTPS/TLS Configuration

### Self-Signed Certificate Generation
```bash
# Generate private key
openssl genrsa -out tls.key 2048

# Generate certificate signing request
openssl req -new -key tls.key -out tls.csr -subj "/CN=golang-ha.example.com"

# Generate self-signed certificate
openssl x509 -req -in tls.csr -signkey tls.key -out tls.crt -days 365

# Create Kubernetes secret
kubectl create secret tls golang-app-tls --cert=tls.crt --key=tls.key
```

### Ingress Configuration
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: golang-app-ingress
  annotations:
    kubernetes.io/ingress.class: "gce"
    networking.gke.io/managed-certificates: "golang-ha-ssl-cert"
spec:
  tls:
  - hosts:
    - golang-ha.example.com
    secretName: golang-app-tls
  rules:
  - host: golang-ha.example.com
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: golang-app-service
            port:
              number: 443
```

## Monitoring and Observability

### Pipeline Metrics
- **Build success rate**: % successful builds
- **Deployment frequency**: Deployments per day
- **Lead time**: Commit to production time
- **MTTR**: Mean time to recovery from failures

### Application Metrics During Deployment
- **Health check status**: /health endpoint responses
- **Error rate**: HTTP 5xx responses per minute  
- **Response time**: P50, P95, P99 latencies
- **Traffic split**: Canary vs stable traffic percentages

### Automated Quality Gates
```yaml
Quality Checks:
- Unit tests: >95% pass rate
- Security scan: Zero high/critical vulnerabilities
- Performance: Response time <100ms P95
- Health checks: 100% success rate for 2 minutes
```
