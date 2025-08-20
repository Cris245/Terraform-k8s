# Golang HA Infrastructure - Architecture Diagram

## Complete Multi-Region GKE Architecture

```mermaid
graph TB
    %% External Users
    Users[External Users] --> LB[Istio Gateway<br/>Load Balancer]
    
    %% Load Balancer Layer
    LB --> HTTPS[HTTPS (443)<br/>SSL Certificate]
    LB --> HTTP[HTTP (80)<br/>Auto-redirect to HTTPS]
    
    %% Primary Region
    subgraph "Primary Region"
        subgraph "GKE Primary Cluster"
            NP1[Node Pool 1<br/>3 nodes<br/>e2-standard-2]
            NP2[Node Pool 2<br/>2 nodes<br/>e2-standard-2<br/>Spot instances]
        end
        
        subgraph "Monitoring Stack"
            PROM[Prometheus<br/>Metrics Collection]
            GRAF[Grafana<br/>Dashboards]
            ALERT[AlertManager<br/>Notifications]
        end
        
        subgraph "Application Layer"
            APP1[Golang App<br/>Deployment]
            SVC1[Service<br/>ClusterIP]
            HPA1[HPA<br/>Auto-scaling]
            APP1_CANARY[Golang App Canary<br/>Single Replica]
        end
        
        subgraph "Istio Service Mesh"
            GATEWAY1[Istio Gateway<br/>Traffic Entry]
            VS1[VirtualService<br/>80/20 Split]
            DR1[DestinationRule<br/>Load Balancing]
        end
        
        subgraph "Security Layer"
            VAULT1[HashiCorp Vault<br/>Secret Management]
            PSP1[Pod Security<br/>Standards]
            NP_SEC1[Network Policies<br/>Traffic Control]
        end
        
        subgraph "Networking"
            VPC1[VPC Network<br/>10.0.1.0/24]
            SUBNET1[Private Subnet<br/>10.0.1.0/26]
            NAT1[Cloud NAT<br/>Outbound Internet]
        end
    end
    
    %% Secondary Region
    subgraph "Secondary Region"
        subgraph "GKE Secondary Cluster"
            NP3[Node Pool 3<br/>2 nodes<br/>e2-standard-2]
            NP4[Node Pool 4<br/>1 node<br/>e2-standard-2<br/>Spot instance]
        end
        
        subgraph "Application Layer DR"
            APP2[Golang App<br/>Deployment]
            SVC2[Service<br/>ClusterIP]
            HPA2[HPA<br/>Auto-scaling]
        end
        
        subgraph "Istio Service Mesh DR"
            GATEWAY2[Istio Gateway<br/>Failover Entry]
            VS2[VirtualService<br/>Failover]
            DR2[DestinationRule<br/>Circuit Breaker]
        end
        
        subgraph "Security Layer DR"
            VAULT2[HashiCorp Vault<br/>HA Replica]
            PSP2[Pod Security<br/>Standards]
            NP_SEC2[Network Policies<br/>Traffic Control]
        end
        
        subgraph "Networking DR"
            VPC2[VPC Network<br/>10.0.2.0/24]
            SUBNET2[Private Subnet<br/>10.0.2.0/26]
            NAT2[Cloud NAT<br/>Outbound Internet]
        end
    end
    
    %% External Services
    subgraph "GCP Services"
        DNS[Cloud DNS<br/>Domain Resolution]
        KMS[Cloud KMS<br/>Encryption Keys]
        SM[Secret Manager<br/>Backup Secrets]
        LOG[Cloud Logging<br/>Centralized Logs]
        MON[Cloud Monitoring<br/>Infrastructure Metrics]
    end
    
    %% CI/CD
    subgraph "CI/CD Pipeline"
        GH[GitHub Actions<br/>Build & Deploy]
        GCR[Container Registry<br/>Image Storage]
        ARGO[ArgoCD<br/>GitOps Controller]
    end
    
    %% Connections
    HTTPS --> GATEWAY1
    HTTP --> GATEWAY1
    
    GATEWAY1 --> VS1
    VS1 --> APP1
    VS1 --> APP1_CANARY
    VS1 --> DR1
    
    APP1 --> SVC1
    APP1_CANARY --> SVC1
    HPA1 --> APP1
    
    PROM --> APP1
    PROM --> APP1_CANARY
    GRAF --> PROM
    ALERT --> PROM
    
    VAULT1 --> APP1
    VAULT1 --> APP1_CANARY
    PSP1 --> APP1
    PSP1 --> APP1_CANARY
    NP_SEC1 --> SVC1
    
    VPC1 --> SUBNET1
    SUBNET1 --> NAT1
    
    %% Cross-region connections
    GATEWAY1 -.-> GATEWAY2
    VS1 -.-> VS2
    VAULT1 -.-> VAULT2
    
    %% External connections
    APP1 --> DNS
    APP2 --> DNS
    APP1 --> KMS
    APP2 --> KMS
    VAULT1 --> SM
    VAULT2 --> SM
    
    %% CI/CD connections
    GH --> GCR
    GCR --> APP1
    GCR --> APP2
    ARGO --> APP1
    ARGO --> APP2
    
    %% Logging and monitoring
    APP1 --> LOG
    APP2 --> LOG
    NP1 --> MON
    NP2 --> MON
    NP3 --> MON
    NP4 --> MON
    
    style Users fill:#e1f5fe
    style LB fill:#f3e5f5
    style APP1 fill:#e8f5e8
    style APP2 fill:#e8f5e8
    style APP1_CANARY fill:#fff3e0
    style PROM fill:#fce4ec
    style GRAF fill:#fce4ec
    style VAULT1 fill:#ffebee
    style VAULT2 fill:#ffebee
```

## Architecture Components

### Primary Region
- **Cluster Name**: golang-ha-primary
- **Node Pools**: 2 pools (5 total nodes)
- **Network**: Private subnet with Cloud NAT
- **Purpose**: Primary production traffic

### Secondary Region  
- **Cluster Name**: golang-ha-secondary
- **Node Pools**: 2 pools (3 total nodes)
- **Network**: Private subnet with Cloud NAT  
- **Purpose**: Failover and disaster recovery

### Service Mesh (Istio)
- **Traffic Management**: 80/20 canary split
- **Security**: mTLS between services
- **Observability**: Distributed tracing
- **Resilience**: Circuit breakers and retries

### Monitoring Stack
- **Prometheus**: Metrics collection from all components
- **Grafana**: Dashboards for visualization
- **AlertManager**: Notification routing
- **Custom Metrics**: Application-specific monitoring

### Security Layer
- **HashiCorp Vault**: Secret management and rotation
- **Pod Security Standards**: Container security policies
- **Network Policies**: Micro-segmentation
- **Istio Security**: Service-to-service encryption

### CI/CD Pipeline
- **GitHub Actions**: Automated build and deployment
- **Container Registry**: Secure image storage
- **ArgoCD**: GitOps-based deployment
- **Canary Strategy**: Progressive deployment with rollback

## Traffic Flow

1. **User Request** → Istio Gateway (Load Balancer)
2. **TLS Termination** → HTTPS/HTTP traffic handling
3. **VirtualService** → 80% to stable, 20% to canary
4. **Service Discovery** → Route to healthy pods
5. **Application** → Process request and return response
6. **Monitoring** → Metrics collected by Prometheus
7. **Logging** → Centralized logging to Cloud Logging

## Failover Mechanism

1. **Health Checks** → Continuous monitoring of primary region
2. **Failure Detection** → Automated detection of unhealthy services
3. **Traffic Switching** → Istio routes traffic to secondary region
4. **Service Recovery** → Automatic scaling and recovery procedures
5. **Failback** → Return to primary when healthy

## Scaling Strategy

### Horizontal Pod Autoscaler (HPA)
- **CPU Utilization**: Scale at 70% CPU usage
- **Memory Utilization**: Scale at 80% memory usage
- **Custom Metrics**: Scale based on HTTP requests per second
- **Min Replicas**: 2 (high availability)
- **Max Replicas**: 10 (cost control)

### Cluster Autoscaler
- **Node Scaling**: Automatic addition/removal of nodes
- **Spot Instances**: Cost optimization for non-critical workloads
- **Multi-zone**: Distribution across availability zones

## Security Architecture

### Network Security
- **Private GKE**: Nodes in private subnets only
- **Authorized Networks**: Restricted API server access
- **Network Policies**: Pod-to-pod traffic control
- **Cloud NAT**: Controlled outbound internet access

### Application Security
- **Pod Security Standards**: Enforced security contexts
- **Service Accounts**: Least privilege access
- **Workload Identity**: Secure GCP service access
- **Container Scanning**: Vulnerability assessment

### Data Security
- **Encryption at Rest**: All persistent data encrypted
- **Encryption in Transit**: TLS for all communications
- **Secret Management**: HashiCorp Vault integration
- **Key Management**: Cloud KMS for encryption keys

## Disaster Recovery

### Recovery Time Objective (RTO): 30 minutes
1. **Detection**: 5 minutes (automated monitoring)
2. **Decision**: 5 minutes (runbook execution)
3. **Execution**: 15 minutes (traffic redirection)
4. **Verification**: 5 minutes (health validation)

### Recovery Point Objective (RPO): 15 minutes
- **Continuous Replication**: Application state sync
- **Database Backups**: 15-minute incremental backups
- **Configuration Sync**: GitOps ensures consistency

## Cost Optimization

### Resource Efficiency
- **Right-sizing**: Pods sized based on actual usage
- **Spot Instances**: Up to 80% cost savings for suitable workloads
- **Auto-scaling**: Scale to zero during low traffic periods
- **Reserved Instances**: Long-term capacity planning

### Monitoring Costs
- **Budget Alerts**: Proactive cost monitoring
- **Resource Quotas**: Prevent resource abuse
- **Cost Attribution**: Per-team/project cost tracking
- **Optimization Recommendations**: Automated suggestions

## Maintenance and Updates

### Rolling Updates
- **Zero Downtime**: No service interruption
- **Gradual Rollout**: Progressive deployment strategy
- **Automated Rollback**: Failure detection and recovery
- **Health Checks**: Continuous validation during updates

### Infrastructure Updates
- **Terraform Plans**: Infrastructure change preview
- **Staged Deployment**: Test in secondary before primary
- **Backup Strategy**: State and configuration backups
- **Validation Testing**: Automated infrastructure testing