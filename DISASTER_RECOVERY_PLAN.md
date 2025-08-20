# Disaster Recovery Plan - Golang HA Server

## Overview

This document outlines the comprehensive disaster recovery strategy for the Golang HA server deployment on GCP, including Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO) definitions.

## Executive Summary

**RTO (Recovery Time Objective)**: 30 minutes  
**RPO (Recovery Point Objective)**: 15 minutes  
**Availability Target**: 99.9% (8.77 hours downtime/year)

## Disaster Scenarios

### 1. Single Pod Failure
**Impact**: Minimal - other pods continue serving traffic  
**Detection**: Kubernetes liveness probes (30 seconds)  
**Recovery**: Automatic pod restart (2-3 minutes)  
**Action Required**: None (automatic)

### 2. Node Failure
**Impact**: Reduced capacity in affected zone  
**Detection**: Node health monitoring (2 minutes)  
**Recovery**: Pod rescheduling to healthy nodes (3-5 minutes)  
**Action Required**: None (automatic via Kubernetes)

### 3. Zone Failure
**Impact**: Reduced regional capacity  
**Detection**: Zone health monitoring (5 minutes)  
**Recovery**: Traffic redistribution to healthy zones (5-10 minutes)  
**Action Required**: Monitor and scale if necessary

### 4. Regional Failure
**Impact**: Complete primary region unavailable  
**Detection**: Regional health monitoring (10 minutes)  
**Recovery**: Failover to secondary region (20-30 minutes)  
**Action Required**: Manual intervention may be required

### 5. Complete Infrastructure Failure
**Impact**: Total service unavailability  
**Detection**: Multi-region monitoring (15 minutes)  
**Recovery**: Full infrastructure rebuild (2-4 hours)  
**Action Required**: Execute full recovery procedures

## Recovery Procedures

### Automated Recovery (RTO: 2-10 minutes)

#### Health Check Configuration
```yaml
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
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

#### Auto-scaling Response
```bash
# HPA automatically scales based on:
# - CPU utilization > 70%
# - Memory utilization > 80%
# - HTTP requests > 100 req/sec per pod
kubectl get hpa golang-app
```

### Manual Failover (RTO: 20-30 minutes)

#### 1. Assess Primary Region Status
```bash
# Check cluster health
gcloud container clusters describe golang-ha-primary --region=YOUR_PRIMARY_REGION

# Check pod status
kubectl get pods --context=gke_YOUR_PROJECT_ID_YOUR_SECONDARY_REGION_golang-ha-secondary

# Check service endpoints
kubectl get endpoints --all-namespaces
```

#### 2. Scale Secondary Region
```bash
# Increase secondary region capacity
kubectl scale deployment golang-app --replicas=5 --context=gke_YOUR_PROJECT_ID_YOUR_SECONDARY_REGION_golang-ha-secondary

# Apply full application stack to secondary
kubectl apply -f application/k8s/ --context=gke_YOUR_PROJECT_ID_YOUR_SECONDARY_REGION_golang-ha-secondary
```

#### 3. Traffic Redirection
```bash
# Update Istio VirtualService for emergency routing
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: emergency-failover
  namespace: golang-app
spec:
  hosts:
  - "*"
  gateways:
  - golang-app-gateway
  http:
  - route:
    - destination:
        host: golang-app-service.golang-app-secondary.svc.cluster.local
        port:
          number: 80
      weight: 100
EOF
```

#### 4. Verify Recovery
```bash
# Test application endpoints
curl -f https://YOUR_LOAD_BALANCER_IP/health
curl -f https://YOUR_LOAD_BALANCER_IP/health
curl -f https://YOUR_LOAD_BALANCER_IP/health

# Check service status
kubectl get service emergency-lb --context=gke_YOUR_PROJECT_ID_YOUR_PRIMARY_REGION_golang-ha-primary
```

### Complete Infrastructure Recovery (RTO: 2-4 hours)

#### 1. Infrastructure Rebuild
```bash
# Set project context
gcloud config set project YOUR_PROJECT_ID

# Rebuild infrastructure
cd infrastructure
terraform destroy -auto-approve  # If necessary
terraform apply -auto-approve

# Deploy applications
kubectl apply -f ../application/k8s/ --context=gke_YOUR_PROJECT_ID_YOUR_PRIMARY_REGION_golang-ha-primary
kubectl apply -f ../application/k8s/ --context=gke_YOUR_PROJECT_ID_YOUR_SECONDARY_REGION_golang-ha-secondary
```

#### 2. Data Recovery
```bash
# Restore from backups (if applicable)
# This example assumes stateless application
# For stateful applications, restore persistent volumes

# Verify data integrity
kubectl exec -it deployment/golang-app -- /app/verify-data
```

## Monitoring and Alerting

### Health Check Endpoints
- **Application Health**: `https://YOUR_LOAD_BALANCER_IP/health`
- **Load Balancer Health**: `https://YOUR_LOAD_BALANCER_IP/`
- **Prometheus Metrics**: `https://YOUR_LOAD_BALANCER_IP/metrics`
- **Grafana Dashboard**: `http://localhost:3000`

### Alert Rules
```yaml
# Primary region unavailable
groups:
- name: disaster_recovery
  rules:
  - alert: PrimaryRegionDown
    expr: up{job="golang-app", region="YOUR_PRIMARY_REGION"} == 0
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: "Primary region is down"
      description: "Primary region has been unavailable for 10 minutes"

  - alert: SecondaryRegionDown
    expr: up{job="golang-app", region="YOUR_SECONDARY_REGION"} == 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Secondary region is down"
      description: "Secondary region has been unavailable for 5 minutes"

  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High error rate detected"
      description: "Error rate is above 10% for 2 minutes"

  - alert: LoadBalancerDown
    expr: probe_success{job="blackbox"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Load balancer is down"
      description: "Global load balancer is not responding"
```

## Recovery Testing Schedule

### Monthly Tests
- **Pod Failure Simulation**: Kill random pods and verify automatic recovery
- **Node Cordoning**: Drain nodes and verify pod rescheduling
- **Health Check Validation**: Verify all monitoring endpoints

### Quarterly Tests
- **Zone Failure Simulation**: Simulate entire zone unavailability
- **Network Partition**: Test behavior during network splits
- **Resource Exhaustion**: Test behavior under resource pressure

### Annual Tests
- **Regional Failover**: Complete primary region failure simulation
- **Infrastructure Rebuild**: Full disaster recovery from scratch
- **Security Incident**: Compromise simulation and recovery

## Communication Plan

### Incident Response Team
- **Incident Commander**: DevOps Lead
- **Technical Lead**: Senior SRE
- **Communications**: Product Manager
- **Subject Matter Expert**: Application Developer

### Communication Channels
1. **Internal**: Slack #incidents channel
2. **Management**: Email to leadership team
3. **External**: Status page updates
4. **Customers**: Email notifications for extended outages

### Escalation Timeline
- **5 minutes**: Alert triggers, on-call engineer notified
- **15 minutes**: Incident commander engaged
- **30 minutes**: Management notification
- **60 minutes**: Customer communication
- **4 hours**: External vendor engagement if needed

## Data Backup and Recovery

### Backup Strategy
```bash
# Application configuration backup
kubectl get all --all-namespaces -o yaml > backup-$(date +%Y%m%d).yaml

# Terraform state backup
gsutil cp terraform.tfstate gs://terraform-state-backup/$(date +%Y%m%d)/

# Secret backup (encrypted)
kubectl get secrets --all-namespaces -o yaml | gpg --encrypt > secrets-backup-$(date +%Y%m%d).gpg
```

### Recovery Verification
- **Data Integrity**: Checksum validation
- **Application Functionality**: End-to-end testing
- **Performance**: Load testing post-recovery
- **Security**: Security scan and validation

## Post-Incident Procedures

### Immediate Actions (Within 24 hours)
1. **Service Restoration**: Confirm full service availability
2. **Initial Assessment**: Preliminary impact analysis
3. **Stakeholder Notification**: Inform all stakeholders of resolution
4. **Evidence Preservation**: Secure logs and artifacts

### Follow-up Actions (Within 1 week)
1. **Root Cause Analysis**: Detailed investigation
2. **Post-Mortem Meeting**: Team review and discussion
3. **Process Improvements**: Update procedures based on learnings
4. **Documentation Updates**: Revise recovery procedures

### Long-term Actions (Within 1 month)
1. **Infrastructure Hardening**: Implement preventive measures
2. **Monitoring Enhancements**: Improve detection capabilities
3. **Training Updates**: Update team training materials
4. **Third-party Reviews**: Consider external security audits

## Key Contacts

### Internal Team
- **On-call Engineer**: Available 24/7 via PagerDuty
- **DevOps Lead**: Primary escalation contact
- **Security Team**: For security-related incidents
- **Product Manager**: Customer communication lead

### External Vendors
- **Google Cloud Support**: Enterprise support contract
- **HashiCorp Support**: Vault enterprise support
- **DNS Provider**: For DNS-related issues
- **CDN Provider**: For edge-related issues

## Success Criteria

### Recovery Objectives Met
- **RTO Achievement**: Recovery within 30 minutes
- **RPO Achievement**: Data loss limited to 15 minutes
- **Availability Target**: Maintain 99.9% uptime annually
- **Customer Impact**: Minimize customer-facing downtime

### Process Effectiveness
- **Detection Time**: Alert within 5 minutes of incident
- **Response Time**: Team engagement within 10 minutes
- **Communication**: Stakeholder notification within established timelines
- **Learning**: Actionable improvements identified and implemented

This disaster recovery plan ensures business continuity and minimizes the impact of potential failures on the Golang HA server infrastructure.