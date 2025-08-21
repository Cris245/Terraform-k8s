# Golang HA Server on GCP

A production-ready, highly available Golang server deployed on Google Cloud Platform using modern SRE methodologies and infrastructure as code practices.

## Project Overview

This repository contains a comprehensive solution demonstrating enterprise-grade DevOps and Platform Engineering capabilities with:

- **Infrastructure**: Terraform + GKE + Multi-region + Monitoring + Auto-scaling
- **CI/CD**: Containers + GitHub Actions + Canary Deployments + Rollback + HTTPS
- **Security**: Zero Trust + Vault + Pod Security + Network Policies
- **GitOps**: Production ArgoCD with HA, RBAC & monitoring + Disaster Recovery Plan

## Architecture Highlights

### Multi-Region High Availability
- **Primary**: Configurable primary region (3 zones) - Production traffic
- **Secondary**: Configurable secondary region (3 zones) - Failover & DR
- **RTO**: <30 minutes | **RPO**: <15 minutes

### Advanced CI/CD Pipeline
- **Canary Deployments**: 80/20 traffic split with validation
- **Automated Rollback**: Health-based failure detection
- **Security Scanning**: Container vulnerability assessment
- **Multi-cluster**: Deployment across regions

### Zero Trust Security
- **Pod Security Standards**: Replacing deprecated PSPs
- **Network Policies**: Micro-segmentation
- **Vault Integration**: Secret management
- **WAF Protection**: Istio WAF-lite at the ingress gateway (deny unsafe methods, block known bad UAs, rate-limit /health and /metrics)
- **Audit Logging**: Comprehensive GCP Cloud Logging with compliance reports
- **HTTPS**: Self-signed certificates on port 443

### Comprehensive Monitoring
- **Prometheus**: Metrics collection and custom metrics
- **Grafana**: Visualization and alerting
- **HPA**: CPU, Memory, and HTTP request-based scaling
- **SLIs/SLOs**: 99.9% availability target

## Quick Start

### Prerequisites
```bash
gcloud --version  # >= 400.0.0
terraform --version  # >= 1.0
kubectl version
docker --version
```

### 1. Configure Project
```bash
# Run the setup script to configure project ID and regions
./setup-project.sh

# Or manually edit the configuration
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project ID and preferred regions
```

### 2. Deploy Infrastructure
```bash
cd infrastructure
terraform init
terraform apply
```

### 3. Configure kubectl
```bash
# Replace YOUR_PROJECT_ID and regions with your actual values
gcloud container clusters get-credentials golang-ha-primary --region YOUR_PRIMARY_REGION --project YOUR_PROJECT_ID
gcloud container clusters get-credentials golang-ha-secondary --region YOUR_SECONDARY_REGION --project YOUR_PROJECT_ID
```

### 4. Deploy Application
```bash
cd ../application
kubectl apply -f k8s-manifests/deployment-simple.yaml
kubectl apply -f istio-config/working-canary-vs.yaml

# Deploy WAF configuration (optional)
kubectl apply -f k8s-manifests/waf-config.yaml
```

### 5. Test Canary Deployment
```bash
# Get Gateway IP
GATEWAY_IP=$(kubectl get service -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test endpoints
curl http://$GATEWAY_IP/health
curl -H "canary: true" http://$GATEWAY_IP/health
curl https://$GATEWAY_IP/health -k

# Run comprehensive tests
./application/scripts/test-working-canary.sh $GATEWAY_IP
```

## Project Structure

```
├── infrastructure/           # Terraform infrastructure code
│   ├── modules/             # Reusable Terraform modules
│   │   ├── vpc/            # VPC and networking
│   │   ├── gke/            # GKE clusters
│   │   ├── monitoring/     # Prometheus/Grafana
│   │   └── argocd/         # GitOps controller
│   └── terraform.tfvars    # Configuration variables
├── application/             # Application and deployment
│   ├── golang-server/      # Go application source
│   ├── k8s-manifests/      # Kubernetes manifests
│   ├── istio-config/       # Service mesh configuration
│   ├── scripts/            # Testing and deployment scripts
│   └── .github/workflows/  # CI/CD pipeline
├── security/               # Security configurations
│   ├── vault-setup.tf      # HashiCorp Vault
│   ├── pod-security-policies.yaml
│   ├── waf-config.yaml     # Web Application Firewall
│   └── audit-logging.yaml # Audit logging
└── docs/                   # Documentation
    ├── ARCHITECTURE_DIAGRAM.md
    └── TECHNICAL_DECISIONS.md
```

## Key Features

### Infrastructure as Code
- **Modular Terraform**: Reusable modules for VPC, GKE, monitoring
- **Multi-region**: Configurable regions with proper networking
- **State Management**: Remote state with GCS backend support
- **Cost Optimization**: Right-sized instances and auto-scaling

### Container Orchestration
- **GKE Autopilot**: Fully managed Kubernetes with best practices
- **Node Pools**: Separate pools for different workload types
- **Auto-scaling**: Both cluster and pod-level scaling
- **Network Policies**: Traffic isolation and security

### Service Mesh
- **Istio**: Traffic management, security, and observability
- **Canary Deployments**: Graduated traffic shifting
- **Circuit Breakers**: Failure isolation and recovery
- **Mutual TLS**: Service-to-service encryption

### CI/CD Pipeline
- **GitHub Actions**: Automated build, test, and deployment
- **Multi-stage**: Build, test, security scan, deploy
- **Canary Strategy**: Progressive delivery with rollback
- **Security Integration**: Vulnerability scanning and compliance

### Monitoring & Observability
- **Prometheus Stack**: Metrics collection and alerting
- **Grafana Dashboards**: Visualization and monitoring
- **Custom Metrics**: Application-specific monitoring
- **Distributed Tracing**: Request flow visibility

### Security & Compliance
- **Zero Trust Model**: Never trust, always verify
- **Pod Security**: Enforced security standards
- **WAF Protection**: Istio gateway policies and Envoy filters
- **Audit Logging**: GCP Cloud Logging with BigQuery analytics and alerting
- **Secret Management**: HashiCorp Vault integration
- **Network Security**: Policies and segmentation

## Testing

### Infrastructure Testing
```bash
# Validate Terraform configuration
./test-infrastructure.sh validate

# Quick health checks
./test-infrastructure.sh quick

# Full infrastructure test
./test-infrastructure.sh full
```

### Application Testing
```bash
# Test application health
kubectl get pods -A
kubectl get services -A

# Load testing
cd application/scripts
./load-test.sh
```

### Canary Deployment Validation
```bash
# Test traffic distribution
./application/scripts/test-working-canary.sh

# Verify canary routing
curl -H "canary: true" http://$GATEWAY_IP/
```

## Configuration

### Region Configuration
The infrastructure supports deployment in any GCP region. Default regions are:
- Primary: europe-west1 (Belgium)
- Secondary: europe-west3 (Frankfurt)

To change regions, edit `infrastructure/terraform.tfvars`:
```hcl
primary_region   = "us-central1"
secondary_region = "us-west1"
regions          = ["us-central1", "us-west1"]
```

### Environment Variables
```bash
export PROJECT_ID="your-gcp-project-id"
export PRIMARY_REGION="europe-west1"
export SECONDARY_REGION="europe-west3"
```

## Service Level Objectives (SLOs)
- **Availability**: 99.9% uptime
- **Latency**: P95 < 500ms, P99 < 1000ms
- **Error Rate**: <0.1% of requests
- **Recovery Time**: RTO < 30 minutes, RPO < 15 minutes

## Cost Optimization
- **Estimated Monthly Cost**: $150-300 (EU regions)
- **Auto-scaling**: Scales to zero during low traffic
- **Preemptible Nodes**: Cost reduction for non-critical workloads
- **Resource Requests**: Right-sized containers

## Documentation

- [Architecture Diagrams](ARCHITECTURE_DIAGRAM.md) - System architecture and data flow
- [Technical Decisions](TECHNICAL_DECISIONS.md) - Engineering choices and rationale
- [Disaster Recovery Plan](DISASTER_RECOVERY_PLAN.md) - DR procedures with RTO/RPO definitions