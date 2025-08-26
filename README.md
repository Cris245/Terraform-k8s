# DevOps Challenge Solution

**Concept demonstration** of production-ready Golang HA infrastructure on GCP with complete CI/CD and security implementation.

> ⚠️ **Important**: This is a conceptual implementation for demonstration purposes. Some components may require additional configuration, testing, or adjustments for production use.

## Structure

```
├── 1_infrastructure/    # Terraform code for GCP HA architecture
├── 2_application/       # Golang app + CI/CD pipeline
├── 3_security/         # Security policies and configurations
├── setup.sh           # Automated deployment script
└── destroy.sh         # Complete cleanup script
```

## Quick Deploy

### Prerequisites
- Google Cloud CLI authenticated
- Terraform >= 1.0
- Docker running
- kubectl and Helm

### Deployment
```bash
# 1. Set your GCP project
export PROJECT_ID="your-gcp-project-id"
gcloud config set project $PROJECT_ID

# 2. Run setup (prepares environment, doesn't deploy)
./setup.sh

# 3. Deploy manually (recommended for evaluation)
cd 1_infrastructure && terraform apply
docker push gcr.io/$PROJECT_ID/golang-ha:latest
kubectl apply -f ../2_application/k8s-manifests/
kubectl apply -f ../3_security/
```

### Manual Deployment (Alternative)

```bash
# 1. Deploy Infrastructure
cd 1_infrastructure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project_id
terraform init
terraform apply

# 2. Build and Deploy Application
cd ../2_application
docker build -t gcr.io/$PROJECT_ID/golang-ha:latest ./golang-server/
docker push gcr.io/$PROJECT_ID/golang-ha:latest
kubectl apply -f k8s-manifests/

# 3. Apply Security Policies
cd ../3_security
kubectl apply -f zero-trust-policies.yaml
kubectl apply -f pod-security-policies.yaml
kubectl apply -f waf-policies.yaml
terraform apply  # For audit logging
```

## Access Services

```bash
# Get cluster credentials
gcloud container clusters get-credentials golang-ha-primary --region us-central1
gcloud container clusters get-credentials golang-ha-secondary --region europe-west1

# Access application
kubectl get svc -A

# Access Grafana monitoring
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# http://localhost:3000 (admin/admin123)

# Access ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443
# https://localhost:8080
```

## Testing

```bash
# Load configuration
source config.env

# Run test suites
./test-cicd.sh      # CI/CD pipeline
./test-canary.sh    # Canary deployments  
./test-dr.sh        # Disaster recovery
./test-monitoring.sh # Monitoring stack
./test-waf.sh       # Security policies
```

## Architecture

- **Multi-region**: us-central1 (primary) + europe-west1 (secondary)
- **Load Balancer**: Global HTTPS with automatic failover
- **Clusters**: GKE with auto-scaling (e2-standard-8 nodes)
- **Monitoring**: Prometheus + Grafana
- **CI/CD**: GitHub Actions with canary deployments
- **Security**: Zero Trust + Vault + WAF + Audit logging

## Cleanup

```bash
# Run cleanup script (basic cleanup)
./destroy.sh

# Verify all resources are deleted manually
gcloud compute instances list
gcloud container clusters list
```

---

## Known Limitations

- **Demonstration Purpose**: Scripts are simplified for challenge evaluation
- **Limited Testing**: Full end-to-end testing was limited due to GCP quota constraints
- **Manual Steps**: Full deployment requires manual verification and configuration
- **GCP Quotas**: Requires sufficient GCP quotas for multi-region deployment
- **Costs**: Will incur GCP charges (estimate: $50-100/day for testing)
- **Production Readiness**: Additional testing and configuration needed for production
- **Certificates**: Uses self-signed certificates (replace with valid ones for production)

## Development Notes

- **Version Control**: Full development history available in Git commits
- **Iterative Development**: Multiple iterations based on testing and troubleshooting
- **GCP Constraints**: Testing limited by quota restrictions and cost considerations
- **Challenge Focus**: Prioritized code completeness over extensive testing

---

**Challenge Requirements Compliance:**
Infrastructure (Terraform + GKE + Multi-region + Monitoring + Auto-scaling)  
Application (CI/CD + Containers + Canary + HTTPS/443)  
Security (Zero Trust + Vault + Pod Security + WAF + Audit)  