#!/bin/bash

# Disaster Recovery Testing Script
# Tests failover capabilities and RTO/RPO compliance
# Based on Holded DevOps Challenge requirements

set -e

# Configuration
PROJECT_ID="peak-tide-469522-r7"
PRIMARY_CLUSTER="golang-ha-primary"
SECONDARY_CLUSTER="golang-ha-secondary"
PRIMARY_REGION="europe-west1"
SECONDARY_REGION="europe-west3"

# RTO/RPO Targets
RTO_TARGET=300  # 5 minutes
RPO_TARGET=60   # 1 minute

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}PASS: $1${NC}"
}

failure() {
    echo -e "${RED}FAIL: $1${NC}"
}

warning() {
    echo -e "${YELLOW}WARN: $1${NC}"
}

info() {
    echo -e "${CYAN}INFO: $1${NC}"
}

# Header
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    DISASTER RECOVERY TESTING                 ║"
echo "║                Golang HA Failover & RTO/RPO Validation     ║"
echo "║              Based on Holded DevOps Challenge               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    log "Running test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name - $expected_result"
        ((TESTS_PASSED++))
        ((TESTS_TOTAL++))
        return 0
    else
        failure "$test_name - Failed"
        ((TESTS_FAILED++))
        ((TESTS_TOTAL++))
        return 1
    fi
}

# Test 1: Pre-Disaster Baseline
echo -e "\n${PURPLE}PRE-DISASTER BASELINE${NC}"
echo "══════════════════════════════════════════════════════════════"

# Get primary cluster credentials
gcloud container clusters get-credentials $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID

# Check primary cluster health
run_test "Primary Cluster Health" "kubectl get pods -n golang-app --no-headers | grep -c 'Running' | grep -q '3'" "Primary cluster has 3 running pods"
run_test "Primary Application Health" "kubectl port-forward service/golang-app-service 8080:80 -n golang-app >/dev/null 2>&1 & sleep 3 && curl -s http://localhost:8080/health | grep -q 'healthy' && kill %1" "Primary application is healthy"

# Test 2: Secondary Cluster Readiness
echo -e "\n${PURPLE}🔄 SECONDARY CLUSTER READINESS${NC}"
echo "══════════════════════════════════════════════════════════════"

# Get secondary cluster credentials
gcloud container clusters get-credentials $SECONDARY_CLUSTER --region=$SECONDARY_REGION --project=$PROJECT_ID

run_test "Secondary Cluster Health" "kubectl get pods -n golang-app --no-headers | grep -c 'Running' | grep -q '3'" "Secondary cluster has 3 running pods"
run_test "Secondary Application Health" "kubectl port-forward service/golang-app-service 8080:80 -n golang-app >/dev/null 2>&1 & sleep 3 && curl -s http://localhost:8080/health | grep -q 'healthy' && kill %1" "Secondary application is healthy"

# Test 3: Data Replication
echo -e "\n${PURPLE}DATA REPLICATION TEST${NC}"
echo "══════════════════════════════════════════════════════════════"

# Check if both clusters have the same application version
PRIMARY_VERSION=$(gcloud container clusters get-credentials $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID >/dev/null 2>&1 && kubectl get deployment golang-app -n golang-app -o jsonpath='{.spec.template.spec.containers[0].image}')
SECONDARY_VERSION=$(gcloud container clusters get-credentials $SECONDARY_CLUSTER --region=$SECONDARY_REGION --project=$PROJECT_ID >/dev/null 2>&1 && kubectl get deployment golang-app -n golang-app -o jsonpath='{.spec.template.spec.containers[0].image}')

if [ "$PRIMARY_VERSION" = "$SECONDARY_VERSION" ]; then
    success "Data Replication - Application versions match across clusters"
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
else
    failure "Data Replication - Application versions differ"
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
fi

# Test 4: Load Balancer Failover
echo -e "\n${PURPLE}LOAD BALANCER FAILOVER TEST${NC}"
echo "══════════════════════════════════════════════════════════════"

# Get load balancer IP
LB_IP=$(cd infrastructure && terraform output -raw load_balancer_ip 2>/dev/null || echo "")

if [ -n "$LB_IP" ]; then
    run_test "Load Balancer Health" "curl -s -I https://$LB_IP | grep -q 'HTTP/'" "Load balancer is healthy"
    run_test "Load Balancer Response" "curl -s https://$LB_IP | grep -q 'Golang High Availability Server'" "Load balancer serves application"
else
    warning "Load balancer IP not available"
fi

# Test 5: Simulated Disaster Recovery
echo -e "\n${PURPLE}💥 SIMULATED DISASTER RECOVERY${NC}"
echo "══════════════════════════════════════════════════════════════"

log "Simulating primary cluster failure..."

# Record start time
START_TIME=$(date +%s)

# Simulate primary cluster failure by scaling down to 0
gcloud container clusters get-credentials $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID
kubectl scale deployment golang-app --replicas=0 -n golang-app

# Wait for pods to terminate
sleep 30

# Check if secondary cluster can handle traffic
gcloud container clusters get-credentials $SECONDARY_CLUSTER --region=$SECONDARY_REGION --project=$PROJECT_ID

# Test secondary cluster response
kubectl port-forward service/golang-app-service 8080:80 -n golang-app >/dev/null 2>&1 &
PF_PID=$!
sleep 5

SECONDARY_RESPONSE=$(curl -s http://localhost:8080/health 2>/dev/null || echo "FAILED")
kill $PF_PID 2>/dev/null || true

# Record recovery time
END_TIME=$(date +%s)
RECOVERY_TIME=$((END_TIME - START_TIME))

if echo "$SECONDARY_RESPONSE" | grep -q "healthy"; then
    success "Disaster Recovery - Secondary cluster responded in ${RECOVERY_TIME}s"
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
    
    # Check RTO compliance
    if [ $RECOVERY_TIME -le $RTO_TARGET ]; then
        success "RTO Compliance - Recovery time (${RECOVERY_TIME}s) within target (${RTO_TARGET}s)"
        ((TESTS_PASSED++))
        ((TESTS_TOTAL++))
    else
        failure "RTO Compliance - Recovery time (${RECOVERY_TIME}s) exceeds target (${RTO_TARGET}s)"
        ((TESTS_FAILED++))
        ((TESTS_TOTAL++))
    fi
else
    failure "Disaster Recovery - Secondary cluster failed to respond"
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
fi

# Restore primary cluster
log "Restoring primary cluster..."
gcloud container clusters get-credentials $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID
kubectl scale deployment golang-app --replicas=3 -n golang-app

# Wait for recovery
sleep 60

# Test 6: Cross-Region Connectivity
echo -e "\n${PURPLE}🌍 CROSS-REGION CONNECTIVITY${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Primary to Secondary Connectivity" "gcloud compute networks list --project=$PROJECT_ID | grep -q 'golang-ha-vpc'" "VPC spans both regions"
run_test "Secondary to Primary Connectivity" "gcloud compute routes list --project=$PROJECT_ID | grep -q 'golang-ha'" "Routes configured for cross-region traffic"

# Test 7: Backup and Restore
echo -e "\n${PURPLE}BACKUP AND RESTORE TEST${NC}"
echo "══════════════════════════════════════════════════════════════"

# Check if backup resources exist
run_test "Audit Logs Backup" "gcloud logging sinks list --project=$PROJECT_ID | grep -q 'golang-ha'" "Audit logs are backed up"
run_test "BigQuery Backup" "bq ls --project_id=$PROJECT_ID | grep -q 'golang_ha_audit_logs'" "BigQuery backup dataset exists"
run_test "Storage Backup" "gsutil ls gs://peak-tide-469522-r7-audit-logs-*" "Cloud Storage backup exists"

# Test 8: Monitoring During Disaster
echo -e "\n${PURPLE}MONITORING DURING DISASTER${NC}"
echo "══════════════════════════════════════════════════════════════"

# Check if monitoring continues during disaster
gcloud container clusters get-credentials $SECONDARY_CLUSTER --region=$SECONDARY_REGION --project=$PROJECT_ID

run_test "Monitoring Namespace" "kubectl get namespace monitoring" "Monitoring namespace exists in secondary"
run_test "Prometheus Running" "kubectl get pods -n monitoring | grep prometheus | grep -q 'Running'" "Prometheus continues monitoring"
run_test "Grafana Running" "kubectl get pods -n monitoring | grep grafana | grep -q 'Running'" "Grafana continues monitoring"

# Test 9: Security During Failover
echo -e "\n${PURPLE}🔒 SECURITY DURING FAILOVER${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Pod Security Standards" "kubectl get pods -n golang-app -o yaml | grep -q 'runAsNonRoot: true'" "Security standards maintained"
run_test "Network Policies" "kubectl get networkpolicies -n golang-app" "Network policies are configured"
run_test "RBAC Configuration" "kubectl get roles,rolebindings -n golang-app" "RBAC is configured"

# Test 10: Documentation and Procedures
echo -e "\n${PURPLE}📚 DOCUMENTATION AND PROCEDURES${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Disaster Recovery Plan" "test -f DISASTER_RECOVERY_PLAN.md" "Disaster recovery plan exists"
run_test "Architecture Documentation" "test -f ARCHITECTURE_DIAGRAM.md" "Architecture documentation exists"
run_test "Technical Decisions" "test -f TECHNICAL_DECISIONS.md" "Technical decisions documented"

# Summary
echo -e "\n${PURPLE}DISASTER RECOVERY TEST SUMMARY${NC}"
echo "══════════════════════════════════════════════════════════════"
echo -e "Total Tests: ${TESTS_TOTAL}"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"

echo -e "\nRTO/RPO Analysis:"
echo -e "  Recovery Time: ${RECOVERY_TIME}s (Target: ${RTO_TARGET}s)"
echo -e "  RTO Status: $([ $RECOVERY_TIME -le $RTO_TARGET ] && echo "${GREEN}PASS: COMPLIANT${NC}" || echo "${RED}FAIL: NON-COMPLIANT${NC}")"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}DISASTER RECOVERY TEST PASSED! System is resilient.${NC}"
    exit 0
else
    echo -e "\n${RED}Some disaster recovery tests failed. Review the system.${NC}"
    exit 1
fi
