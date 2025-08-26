# Infrastructure Architecture

## Complete Architecture Diagram

```
                    Internet/Users
                          |
                    Cloud Load Balancer
                    (Global HTTP(S) LB)
                          |
        +-----------------+-----------------+
        |                                 |
    US-Central1                    Europe-West1
   (Primary Region)               (Secondary Region)
        |                                 |
    GKE Cluster                      GKE Cluster
  golang-ha-primary               golang-ha-secondary
        |                                 |
   +----+----+                      +----+----+
   |         |                      |         |
App Pods  Monitor                App Pods  Monitor
  (3x)    Stack                    (3x)    Stack
   |         |                      |         |
   |    Prometheus                  |    Prometheus
   |    Grafana                     |    Grafana
   |    ArgoCD                      |    ArgoCD
   |         |                      |         |
VPC Network |                  VPC Network   |
10.0.3.0/24 |                  10.0.1.0/24   |
        |   |                          |     |
     NAT Gateway                    NAT Gateway
        |   |                          |     |
    Cloud Router                   Cloud Router
        |   |                          |     |
        +---+----------+------+--------+-----+
                       |      |
                  BigQuery  Cloud Storage
                (Audit Logs) (Log Archive)
```

## High Availability Design

### Multi-Region Failover Architecture

**Primary Region: us-central1 (Iowa)**
- **Purpose**: Main production traffic
- **Capacity**: 3x e2-standard-8 nodes (24 vCPUs, 96GB RAM)
- **Storage**: 80GB SSD per node
- **Availability Zones**: us-central1-a, us-central1-b, us-central1-c

**Secondary Region: europe-west1 (Belgium)**
- **Purpose**: Failover + EU traffic compliance
- **Capacity**: 3x e2-standard-8 nodes (identical to primary)
- **Storage**: 80GB SSD per node
- **Availability Zones**: europe-west1-b, europe-west1-c, europe-west1-d

### Auto-Scaling Policies

**Cluster Auto-Scaling:**
```yaml
Node Pool Configuration:
- Min nodes: 3 per region
- Max nodes: 9 per region
- Scale up threshold: CPU > 70% for 5 minutes
- Scale down threshold: CPU < 30% for 10 minutes
```

**Pod Auto-Scaling (HPA):**
```yaml
Horizontal Pod Autoscaler:
- Min replicas: 3 per region
- Max replicas: 15 per region
- CPU target: 70%
- Memory target: 80%
- Custom metrics: request_rate > 100 RPS
```

**Vertical Pod Autoscaler (VPA):**
```yaml
Resource Right-Sizing:
- CPU: 250m-1000m
- Memory: 256Mi-1Gi
- Update mode: Auto
```

## Monitoring Stack

### Prometheus Configuration
- **Retention**: 15 days local storage
- **Scrape interval**: 30 seconds
- **High availability**: 2 replicas per region
- **Federation**: Cross-region metrics sync

### Grafana Dashboards
- **Application metrics**: Response time, error rate, throughput
- **Infrastructure metrics**: CPU, memory, disk, network
- **Business metrics**: Active users, transactions
- **SLA/SLI tracking**: 99.9% uptime target

### Custom Metrics
```yaml
Application Metrics:
- http_requests_total (counter)
- http_request_duration_seconds (histogram)
- active_connections (gauge)
- golang_ha_health_status (gauge)
```

## Network Architecture

### VPC Design
- **CIDR**: 10.0.0.0/16 (global)
- **Primary subnet**: 10.0.3.0/24 (us-central1)
- **Secondary subnet**: 10.0.1.0/24 (europe-west1)
- **Private clusters**: No public node IPs
- **Authorized networks**: Master access via Cloud Shell only

### Traffic Flow
1. **Ingress**: Global Load Balancer → Regional backends
2. **East-West**: Service mesh with mTLS (future Istio)
3. **Egress**: NAT Gateway → Internet
4. **Internal**: Private Google Access for APIs

## Technology Decisions

### Why Multi-Region vs Multi-Zone?

**Decision**: Multi-region deployment across continents
**Reasoning**:
- **Disaster resilience**: Regional disasters (earthquakes, data center outages)
- **Compliance**: EU data residency requirements
- **Performance**: Reduced latency for global users
- **Business continuity**: No single point of failure

### Why GKE vs Compute Engine?

**Decision**: Google Kubernetes Engine (GKE)
**Reasoning**:
- **Managed control plane**: No master node maintenance
- **Auto-upgrades**: Security patches and version updates
- **Native scaling**: HPA, VPA, and cluster autoscaler
- **Integration**: Native GCP service integration
- **Operational overhead**: Reduced ops complexity

### Why e2-standard-8 nodes?

**Decision**: 8 vCPU, 32GB RAM per node
**Reasoning**:
- **Resource density**: Optimal pod-to-node ratio
- **Performance**: Sufficient for production workloads
- **Cost efficiency**: Better than smaller nodes with overhead
- **Scaling headroom**: Can handle traffic spikes

### Why Prometheus vs Cloud Monitoring?

**Decision**: Prometheus + Grafana stack
**Reasoning**:
- **Custom metrics**: Application-specific monitoring
- **Query flexibility**: PromQL for complex queries
- **Alerting**: Advanced alert routing with AlertManager
- **Portability**: Vendor-agnostic monitoring
- **Community**: Extensive ecosystem and dashboards

## Terraform Modules

### Module Structure
```
modules/
├── vpc/              # Network infrastructure
├── gke/              # Kubernetes clusters
├── load_balancer/    # Global HTTP(S) LB
├── monitoring/       # Prometheus + Grafana
├── application/      # App deployments
├── argocd/          # GitOps controller
└── audit-logging/   # Security audit logs
```

### Module Benefits
- **Reusability**: Same modules for dev/staging/prod
- **Testing**: Independent module validation
- **Ownership**: Teams can own specific modules
- **Versioning**: Module versioning for stability
- **Composition**: Mix and match for different environments
