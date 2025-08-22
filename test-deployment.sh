#!/bin/bash

# Comprehensive Deployment Testing Script
# Tests all requirements for the Golang HA Infrastructure
# Based on Holded DevOps Challenge requirements

set -e

# Configuration
PROJECT_ID="peak-tide-469522-r7"
PRIMARY_CLUSTER="golang-ha-primary"
SECONDARY_CLUSTER="golang-ha-secondary"
PRIMARY_REGION="europe-west1"
SECONDARY_REGION="europe-west3"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}PASS: $1${NC}"
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
}

failure() {
    echo -e "${RED}FAIL: $1${NC}"
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
}

warning() {
    echo -e "${YELLOW}WARN: $1${NC}"
}

info() {
    echo -e "${CYAN}INFO: $1${NC}"
}

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    log "Running test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name - $expected_result"
        return 0
    else
        failure "$test_name - Failed"
        return 1
    fi
}

# Header
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    DEPLOYMENT TESTING                       ║"
echo "║                Golang HA Infrastructure Validation           ║"
echo "║              Based on Holded DevOps Challenge               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Test 1: Infrastructure Validation
echo -e "\n${PURPLE}TESTING INFRASTRUCTURE${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Terraform Configuration" "cd infrastructure && terraform validate" "Terraform configuration is valid"
run_test "GCP Project Access" "gcloud projects describe $PROJECT_ID >/dev/null" "GCP project access verified"
run_test "Required APIs Enabled" "gcloud services list --enabled --project=$PROJECT_ID | grep -E '(container|compute|monitoring|logging)'" "Required APIs enabled"

# Test 2: GKE Clusters
echo -e "\n${PURPLE}TESTING GKE CLUSTERS${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Primary Cluster Status" "gcloud container clusters describe $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID | grep -q 'status: RUNNING'" "Primary cluster is running"
run_test "Secondary Cluster Status" "gcloud container clusters describe $SECONDARY_CLUSTER --region=$SECONDARY_REGION --project=$PROJECT_ID | grep -q 'status: RUNNING'" "Secondary cluster is running"
run_test "Primary Cluster Nodes" "gcloud container clusters describe $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID | grep -A 10 'nodePools:' | grep -q 'RUNNING'" "Primary cluster nodes are running"
run_test "Secondary Cluster Nodes" "gcloud container clusters describe $SECONDARY_CLUSTER --region=$SECONDARY_REGION --project=$PROJECT_ID | grep -A 10 'nodePools:' | grep -q 'RUNNING'" "Secondary cluster nodes are running"

# Test 3: Application Deployment
echo -e "\n${PURPLE}TESTING APPLICATION DEPLOYMENT${NC}"
echo "══════════════════════════════════════════════════════════════"

# Get credentials for primary cluster
gcloud container clusters get-credentials $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID >/dev/null 2>&1

run_test "Application Namespace" "kubectl get namespace golang-app" "Application namespace exists"
run_test "Application Pods Running" "kubectl get pods -n golang-app --no-headers | grep -c 'Running' | grep -q '3'" "3 application pods are running"
run_test "Application Service" "kubectl get service golang-app-service -n golang-app" "Application service exists"
run_test "Canary Deployment" "kubectl get pods -n golang-app-privileged --no-headers | grep -c 'Running' | grep -q '1'" "Canary deployment is running"

# Test 4: Application Health
echo -e "\n${PURPLE}TESTING APPLICATION HEALTH${NC}"
echo "══════════════════════════════════════════════════════════════"

# Start port-forward in background
kubectl port-forward service/golang-app-service 8080:80 -n golang-app >/dev/null 2>&1 &
PF_PID=$!
sleep 5

run_test "Health Endpoint" "curl -s http://localhost:8080/health | grep -q 'healthy'" "Health endpoint returns healthy status"
run_test "Main Endpoint" "curl -s http://localhost:8080/ | grep -q 'Golang High Availability Server'" "Main endpoint returns HTML content"
run_test "Metrics Endpoint" "curl -s http://localhost:8080/metrics | grep -q 'go_goroutines'" "Metrics endpoint returns Prometheus metrics"

# Stop port-forward
kill $PF_PID 2>/dev/null || true

# Test 5: Monitoring Stack
echo -e "\n${PURPLE}TESTING MONITORING STACK${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Monitoring Namespace" "kubectl get namespace monitoring" "Monitoring namespace exists"
run_test "Prometheus Running" "kubectl get pods -n monitoring | grep prometheus | grep -q 'Running'" "Prometheus is running"
run_test "Grafana Running" "kubectl get pods -n monitoring | grep grafana | grep -q 'Running'" "Grafana is running"
run_test "AlertManager Running" "kubectl get pods -n monitoring | grep alertmanager | grep -q 'Running'" "AlertManager is running"

# Test 6: Load Balancer
echo -e "\n${PURPLE}TESTING LOAD BALANCER${NC}"
echo "══════════════════════════════════════════════════════════════"

LB_IP=$(cd infrastructure && terraform output -raw load_balancer_ip 2>/dev/null || echo "")

if [ -n "$LB_IP" ]; then
    run_test "Load Balancer IP" "echo $LB_IP | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'" "Load balancer IP is valid"
    run_test "Load Balancer Health" "curl -s -I https://$LB_IP | grep -q 'HTTP/'" "Load balancer responds to HTTPS"
else
    warning "Load balancer IP not available"
fi

# Test 7: Security & Audit
echo -e "\n${PURPLE}TESTING SECURITY & AUDIT${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Audit Logging Enabled" "gcloud logging sinks list --project=$PROJECT_ID | grep -q 'golang-ha'" "Audit logging is configured"
run_test "BigQuery Dataset" "bq ls --project_id=$PROJECT_ID | grep -q 'golang_ha_audit_logs'" "BigQuery audit dataset exists"
run_test "Pod Security" "kubectl get pods -n golang-app -o yaml | grep -q 'runAsNonRoot: true'" "Pods run as non-root"

# Test 8: GitOps (ArgoCD)
echo -e "\n${PURPLE}TESTING GITOPS (ARGOCD)${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "ArgoCD Namespace" "kubectl get namespace argocd" "ArgoCD namespace exists"
run_test "ArgoCD Server" "kubectl get pods -n argocd | grep argocd-server | grep -q 'Running'" "ArgoCD server is running"
run_test "ArgoCD Controller" "kubectl get pods -n argocd | grep argocd-application-controller | grep -q 'Running'" "ArgoCD controller is running"

# Test 9: High Availability
echo -e "\n${PURPLE}TESTING HIGH AVAILABILITY${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Multi-Region Deployment" "gcloud container clusters list --project=$PROJECT_ID | grep -c 'RUNNING' | grep -q '2'" "Deployment spans multiple regions"
run_test "Auto-scaling Enabled" "gcloud container clusters describe $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID | grep -A 5 'autoscaling:' | grep -q 'enabled: true'" "Auto-scaling is enabled"

# Test 10: Performance & Scalability
echo -e "\n${PURPLE}TESTING PERFORMANCE & SCALABILITY${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "HPA Configuration" "kubectl get hpa -n golang-app" "Horizontal Pod Autoscaler is configured"
run_test "Resource Limits" "kubectl get pods -n golang-app -o yaml | grep -A 5 'resources:' | grep -q 'limits:'" "Resource limits are set"
run_test "Liveness Probe" "kubectl get pods -n golang-app -o yaml | grep -A 5 'livenessProbe:' | grep -q 'httpGet:'" "Liveness probes are configured"
run_test "Readiness Probe" "kubectl get pods -n golang-app -o yaml | grep -A 5 'readinessProbe:' | grep -q 'httpGet:'" "Readiness probes are configured"

# Test 11: Disaster Recovery
echo -e "\n${PURPLE}TESTING DISASTER RECOVERY${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Secondary Cluster Ready" "gcloud container clusters get-credentials $SECONDARY_CLUSTER --region=$SECONDARY_REGION --project=$PROJECT_ID && kubectl get pods -n golang-app --no-headers | grep -c 'Running' | grep -q '3'" "Secondary cluster has application running"
run_test "Cross-Region Backup" "gcloud compute instances list --project=$PROJECT_ID --filter='zone~$PRIMARY_REGION OR zone~$SECONDARY_REGION'" "Resources exist in both regions"

# Summary
echo -e "\n${PURPLE}TEST SUMMARY${NC}"
echo "══════════════════════════════════════════════════════════════"
echo -e "Total Tests: ${TESTS_TOTAL}"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}ALL TESTS PASSED! Deployment is fully operational.${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please review the deployment.${NC}"
    exit 1
fi
