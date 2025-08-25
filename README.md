# Golang HA Infrastructure - Holded DevOps Challenge

A complete, production-ready Golang high-availability infrastructure deployed on Google Cloud Platform using Terraform and Kubernetes.

## 🎯 Challenge Requirements

This solution addresses all requirements from the [Holded DevOps Challenge](https://github.com/holdedhub/careers/tree/main/challenges/devops):

### 1. Infrastructure
- **Terraform**: Complete Infrastructure as Code
- **Kubernetes (GKE)**: Multi-region clusters
- **Multi-region failover**: Primary (europe-west1) + Secondary (europe-west3)
- **Monitoring stack**: Prometheus + Grafana
- **Auto-scaling**: Based on custom metrics
- **Architecture diagram**: Complete documentation
- **Modular Terraform**: Reusable modules
- **GitOps**: ArgoCD implementation
- **Disaster recovery**: RTO/RPO definitions

### 2. Application (CI/CD)
- **Containers**: Docker-based automation
- **CI pipeline**: GitHub Actions deployment to GCP
- **Canary deployments**: Traffic distribution
- **Automated rollback**: Failure detection and recovery
- **Port 443**: SSL/TLS with self-signed certificates

### 3. Security
- **Zero Trust**: Network security policies
- **Vault**: HashiCorp Vault for secrets
- **Pod Security**: Security policies implemented
- **WAF**: Web Application Firewall (Istio-based)
- **Audit logging**: Comprehensive logging system

## Quick Start

### Prerequisites
- Google Cloud CLI (`gcloud`)
- Terraform
- Docker
- Kubectl
- Helm

### 1. Setup and Deploy
```bash
# Clone the repository
git clone <repository-url>
cd Terraform-k8s

# Run the complete setup (takes 15-20 minutes)
./setup.sh
```

### 2. Test the Infrastructure
```bash
# Load configuration
source config.env

# Test CI/CD functionality
./test-cicd.sh

# Test canary deployments
./test-canary.sh

# Test disaster recovery
./test-dr.sh
```

### 3. Cleanup
```bash
# Destroy all resources
./destroy.sh
```

## Simplified Structure

```
├── setup.sh              # Complete setup and deployment
├── test-cicd.sh          # CI/CD testing (Holded requirements)
├── test-canary.sh        # Canary testing (Holded requirements)
├── test-dr.sh            # Disaster recovery testing (Holded requirements)
├── destroy.sh            # Cleanup all resources
├── config.env            # Generated configuration
├── infrastructure/       # Terraform modules
├── application/          # Golang application
└── docs/                # Documentation
```

## Testing Strategy

### CI/CD Testing (`test-cicd.sh`)
- Container build and push
- Application deployment
- Canary deployments
- Multi-cluster deployment
- Load balancer and SSL
- Automated rollback simulation

### Canary Testing (`test-canary.sh`)
- Canary deployment health
- Production vs canary comparison
- Health monitoring
- Traffic distribution simulation
- Rollback functionality

### Disaster Recovery Testing (`test-dr.sh`)
- Multi-region failover architecture
- Load balancer failover
- Cross-region data replication
- RTO validation (target: ≤60s)
- RPO validation
- Application health after failover

## Architecture

### Multi-Region Setup
- **Primary**: europe-west1 (Belgium)
- **Secondary**: europe-west3 (Frankfurt)
- **Load Balancer**: Global HTTP(S) load balancer
- **Networking**: VPC with private clusters

### Components
- **GKE Clusters**: 2 clusters with auto-scaling
- **Application**: Golang server with 3 replicas + canary
- **Monitoring**: Prometheus + Grafana stack
- **GitOps**: ArgoCD for continuous deployment
- **Security**: Vault, WAF, audit logging
- **Load Balancer**: SSL termination and health checks

## Monitoring & Observability

- **Application Metrics**: Custom Prometheus metrics
- **Infrastructure**: GCP Cloud Monitoring
- **Logging**: Cloud Logging with BigQuery
- **Alerts**: Automated alerting for failures
- **Dashboards**: Grafana dashboards for visualization

## Security Features

- **Zero Trust**: Network policies and service mesh
- **Secrets Management**: HashiCorp Vault
- **Pod Security**: Security policies and RBAC
- **WAF**: Istio-based web application firewall
- **Audit Logging**: Comprehensive security logging
- **SSL/TLS**: End-to-end encryption

## Auto-scaling

- **HPA**: Horizontal Pod Autoscaler
- **VPA**: Vertical Pod Autoscaler
- **Custom Metrics**: Application-specific scaling
- **Node Auto-scaling**: Cluster-level scaling

## RTO/RPO Targets

- **RTO (Recovery Time Objective)**: ≤60 seconds
- **RPO (Recovery Point Objective)**: Near-zero data loss
- **Failover**: Automatic cross-region failover
- **Testing**: Automated DR testing included

## Documentation

- [Architecture Diagram](docs/ARCHITECTURE_DIAGRAM.md)
- [Technical Decisions](docs/TECHNICAL_DECISIONS.md)
- [Disaster Recovery Plan](docs/DISASTER_RECOVERY_PLAN.md)
- [Interview Summary](docs/INTERVIEW_SUMMARY.md)

## Contributing

This solution is designed to be easily testable by anyone:
1. Clone the repository
2. Run `./setup.sh`
3. Test with the provided scripts
4. Clean up with `./destroy.sh`

All scripts are self-contained and will work with any GCP project.