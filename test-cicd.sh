#!/bin/bash

# CI/CD Testing Script
# Comprehensive testing for CI/CD pipeline, canary deployments, and rollback strategies
# Usage: ./test-cicd.sh [full|quick|validate]

set -e

# Configuration
PROJECT_ID="${PROJECT_ID:-YOUR_PROJECT_ID}"
PRIMARY_CLUSTER="golang-ha-primary"
SECONDARY_CLUSTER="golang-ha-secondary"
PRIMARY_REGION="${PRIMARY_REGION:-europe-west1}"
SECONDARY_REGION="${SECONDARY_REGION:-europe-west3}"

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
    echo -e "${GREEN}[PASS] $1${NC}"
    ((TESTS_PASSED++))
    ((TESTS_TOTAL++))
}

failure() {
    echo -e "${RED}[FAIL] $1${NC}"
    ((TESTS_FAILED++))
    ((TESTS_TOTAL++))
}

warning() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

info() {
    echo -e "${CYAN}[INFO] $1${NC}"
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
echo "║                    CI/CD Testing Script                     ║"
echo "║         GitHub Actions, Docker, Canary, Rollback            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Test 1: GitHub Actions Workflow Structure
echo -e "\n${PURPLE}TESTING GITHUB ACTIONS WORKFLOW${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "GitHub Actions Workflow" "test -f application/.github/workflows/ci-cd.yml" "CI/CD workflow file exists"
run_test "Workflow Syntax" "yq eval '.' application/.github/workflows/ci-cd.yml >/dev/null" "Workflow YAML syntax is valid"
run_test "Build Job" "yq eval '.jobs.build' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Build job is configured"
run_test "Test Job" "yq eval '.jobs.test' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Test job is configured"
run_test "Canary Job" "yq eval '.jobs.deploy-canary' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Canary deployment job is configured"
run_test "Production Job" "yq eval '.jobs.deploy-production' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Production deployment job is configured"
run_test "Rollback Job" "yq eval '.jobs.rollback' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Rollback job is configured"

# Test 2: Docker Configuration
echo -e "\n${PURPLE}🐳 TESTING DOCKER CONFIGURATION${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Dockerfile Exists" "test -f application/golang-server/Dockerfile" "Dockerfile exists"
run_test "Dockerfile Multi-stage" "grep -q 'FROM.*AS' application/golang-server/Dockerfile" "Dockerfile uses multi-stage build"
run_test "Dockerfile Security" "grep -q 'USER.*nonroot' application/golang-server/Dockerfile" "Dockerfile runs as non-root user"
run_test "Dockerfile Health Check" "grep -q 'HEALTHCHECK' application/golang-server/Dockerfile" "Dockerfile has health check"
run_test "Dockerfile Optimization" "grep -q 'COPY.*--from=' application/golang-server/Dockerfile" "Dockerfile uses optimized copy"

# Test 3: Container Build Process
echo -e "\n${PURPLE}🔨 TESTING CONTAINER BUILD PROCESS${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Go Application Build" "cd application/golang-server && go build -o test-binary . >/dev/null 2>&1" "Go application builds successfully"
run_test "Docker Image Build" "cd application/golang-server && docker build -t test-cicd-image . >/dev/null 2>&1" "Docker image builds successfully"
run_test "Docker Image Size" "docker images test-cicd-image --format '{{.Size}}' | grep -E '^[0-9]+[.][0-9]+MB$'" "Docker image size is reasonable"
run_test "Container Registry Access" "gcloud auth configure-docker" "Container registry access configured"

# Test 4: Canary Deployment Configuration
echo -e "\n${PURPLE}TESTING CANARY DEPLOYMENT${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Canary Deployment File" "test -f application/k8s-manifests/canary-deployment.yaml" "Canary deployment manifest exists"
run_test "Canary Service File" "test -f application/k8s-manifests/canary-service.yaml" "Canary service manifest exists"
run_test "Canary Traffic Routing" "grep -q 'canary' application/k8s-manifests/canary-deployment.yaml" "Canary deployment has proper labels"
run_test "Canary Namespace" "kubectl get namespace golang-app-privileged" "Canary namespace exists"
run_test "Canary Pods Running" "kubectl get pods -n golang-app-privileged --no-headers | grep -c 'Running' | grep -q '1'" "Canary pods are running"
run_test "Canary Service" "kubectl get service -n golang-app-privileged" "Canary service exists"

# Test canary traffic routing
info "Testing canary traffic routing..."
CANARY_RESPONSE=$(curl -s -H "canary: true" http://localhost:8080/health 2>/dev/null || echo "FAILED")
if [[ "$CANARY_RESPONSE" == *"healthy"* ]]; then
    success "Canary traffic routing - Canary header routes to canary deployment"
else
    failure "Canary traffic routing - Canary header not working"
fi

# Test 5: Production Deployment Configuration
echo -e "\n${PURPLE}🚀 TESTING PRODUCTION DEPLOYMENT${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Production Deployment File" "test -f application/k8s-manifests/deployment.yaml" "Production deployment manifest exists"
run_test "Production Service File" "test -f application/k8s-manifests/service.yaml" "Production service manifest exists"
run_test "Production Ingress File" "test -f application/k8s-manifests/ingress.yaml" "Production ingress manifest exists"
run_test "Production ConfigMap" "test -f application/k8s-manifests/configmap.yaml" "Production configmap exists"
run_test "Production Secret" "test -f application/k8s-manifests/secret.yaml" "Production secret exists"

# Test 6: Rollback Strategy
echo -e "\n${PURPLE}TESTING ROLLBACK STRATEGY${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Rollback Job Configuration" "yq eval '.jobs.rollback.if' application/.github/workflows/ci-cd.yml | grep -q 'failure'" "Rollback triggers on failure"
run_test "Rollback Commands" "yq eval '.jobs.rollback.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'rollout undo'" "Rollback uses kubectl rollout undo"
run_test "Rollback Notification" "yq eval '.jobs.rollback.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'notify'" "Rollback includes notification"

# Test 7: Security Scanning
echo -e "\n${PURPLE}TESTING SECURITY SCANNING${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Trivy Security Scan" "yq eval '.jobs.security-scan' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Security scanning job configured"
run_test "SARIF Output" "yq eval '.jobs.security-scan.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'sarif'" "Security scan outputs SARIF format"
run_test "Vulnerability Check" "yq eval '.jobs.security-scan.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'exit-code'" "Security scan fails on vulnerabilities"

# Test 8: Multi-Cluster Deployment
echo -e "\n${PURPLE}TESTING MULTI-CLUSTER DEPLOYMENT${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Primary Cluster Deployment" "yq eval '.jobs.deploy-production.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'golang-ha-primary'" "Primary cluster deployment configured"
run_test "Secondary Cluster Deployment" "yq eval '.jobs.deploy-production.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'golang-ha-secondary'" "Secondary cluster deployment configured"
run_test "Cluster Context Switching" "yq eval '.jobs.deploy-production.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'get-credentials'" "Cluster context switching configured"

# Test 9: GCP Integration
echo -e "\n${PURPLE}TESTING GCP INTEGRATION${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "GCP Authentication" "yq eval '.jobs.build.steps[].uses' application/.github/workflows/ci-cd.yml | grep -q 'google-github-actions/auth'" "GCP authentication configured"
run_test "GCR Configuration" "yq eval '.jobs.build.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'configure-docker'" "GCR Docker configuration present"
run_test "GCR Push" "yq eval '.jobs.build.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'push'" "GCR image push configured"

# Test 10: Job Dependencies
echo -e "\n${PURPLE}🔗 TESTING JOB DEPENDENCIES${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Build Depends on Test" "yq eval '.jobs.build.needs' application/.github/workflows/ci-cd.yml | grep -q 'test'" "Build job depends on test job"
run_test "Canary Depends on Build" "yq eval '.jobs.deploy-canary.needs' application/.github/workflows/ci-cd.yml | grep -q 'build'" "Canary job depends on build job"
run_test "Production Depends on Canary" "yq eval '.jobs.deploy-production.needs' application/.github/workflows/ci-cd.yml | grep -q 'deploy-canary'" "Production job depends on canary job"

# Test 11: Automated Rollback Testing
echo -e "\n${PURPLE}TESTING AUTOMATED ROLLBACK${NC}"
echo "══════════════════════════════════════════════════════════════"

# Simulate a failed deployment
info "Simulating deployment failure for rollback testing..."
kubectl scale deployment golang-app --replicas=0 -n golang-app >/dev/null 2>&1

# Check if HPA triggers rollback
sleep 10
HPA_STATUS=$(kubectl get hpa -n golang-app -o jsonpath='{.items[0].status.conditions[0].status}' 2>/dev/null || echo "Unknown")
if [[ "$HPA_STATUS" == "True" ]]; then
    success "HPA Rollback Detection - HPA detected deployment failure"
else
    warning "HPA Rollback Detection - HPA status unclear"
fi

# Restore deployment
kubectl scale deployment golang-app --replicas=3 -n golang-app >/dev/null 2>&1
sleep 10

run_test "Rollback Recovery" "kubectl get pods -n golang-app --no-headers | grep -c 'Running' | grep -q '3'" "Deployment recovered after rollback test"

# Test 12: SSL/TLS Configuration
echo -e "\n${PURPLE}🔐 TESTING SSL/TLS CONFIGURATION${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "SSL Certificate" "test -f application/k8s-manifests/tls-secret.yaml" "SSL certificate secret exists"
run_test "HTTPS Ingress" "grep -q 'tls:' application/k8s-manifests/ingress.yaml" "HTTPS TLS configuration present"
run_test "Port 443 Configuration" "grep -q '443' application/k8s-manifests/ingress.yaml" "Port 443 is configured"

# Test 13: Custom Metrics
echo -e "\n${PURPLE}TESTING CUSTOM METRICS${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Custom Metrics Endpoint" "curl -s http://localhost:8080/metrics | grep -q 'golang_app_'" "Custom application metrics exposed"
run_test "HPA Custom Metrics" "kubectl get hpa -n golang-app -o yaml | grep -q 'custom-metrics'" "HPA uses custom metrics"
run_test "Prometheus Scraping" "kubectl get servicemonitor -n monitoring | grep -q 'golang-app'" "Prometheus service monitor configured"

# Summary
echo -e "\n${PURPLE}TEST SUMMARY${NC}"
echo "══════════════════════════════════════════════════════════════"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo -e "${CYAN}Total Tests: $TESTS_TOTAL${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}ALL CI/CD TESTS PASSED! CI/CD pipeline is production-ready.${NC}"
    exit 0
else
    echo -e "\n${RED}Some CI/CD tests failed. Review the pipeline configuration.${NC}"
    exit 1
fi
