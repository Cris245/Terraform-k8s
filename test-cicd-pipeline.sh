#!/bin/bash

# CI/CD Pipeline Validation Script
# Tests all CI/CD components required for the Holded DevOps Challenge
# Validates GitHub Actions, Docker builds, canary deployments, and rollback strategies

set -e

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
echo "║                CI/CD PIPELINE VALIDATION                    ║"
echo "║           Holded DevOps Challenge Requirements               ║"
echo "║         GitHub Actions, Docker, Canary, Rollback            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Test 1: GitHub Actions Workflow Structure
echo -e "\n${PURPLE}TESTING GITHUB ACTIONS WORKFLOW${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Workflow File Exists" "test -f application/.github/workflows/ci-cd.yml" "CI/CD workflow file exists"
run_test "Workflow Syntax" "yq eval '.name' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Workflow YAML syntax is valid"
run_test "Workflow Triggers" "yq eval '.on.push.branches' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Workflow has proper triggers"

# Test 2: CI/CD Pipeline Jobs
echo -e "\n${PURPLE}TESTING CI/CD PIPELINE JOBS${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Test Job" "yq eval '.jobs.test' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Test job is configured"
run_test "Build Job" "yq eval '.jobs.build' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Build job is configured"
run_test "Canary Job" "yq eval '.jobs.deploy-canary' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Canary deployment job is configured"
run_test "Production Job" "yq eval '.jobs.deploy-production' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Production deployment job is configured"
run_test "Rollback Job" "yq eval '.jobs.rollback' application/.github/workflows/ci-cd.yml >/dev/null 2>&1" "Rollback job is configured"

# Test 3: Docker Configuration
echo -e "\n${PURPLE}TESTING DOCKER CONFIGURATION${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Dockerfile Exists" "test -f application/golang-server/Dockerfile" "Dockerfile exists"
run_test "Dockerfile Multi-stage" "grep -q 'FROM.*AS' application/golang-server/Dockerfile" "Dockerfile uses multi-stage build"
run_test "Dockerfile Security" "grep -q 'USER.*nonroot' application/golang-server/Dockerfile" "Dockerfile runs as non-root user"
run_test "Dockerfile Health Check" "grep -q 'HEALTHCHECK' application/golang-server/Dockerfile" "Dockerfile has health check"

# Test 4: Container Build Process
echo -e "\n${PURPLE}TESTING CONTAINER BUILD PROCESS${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Go Application Build" "cd application/golang-server && go build -o test-binary . >/dev/null 2>&1" "Go application builds successfully"
run_test "Docker Image Build" "cd application/golang-server && docker build -t test-cicd-image . >/dev/null 2>&1" "Docker image builds successfully"
run_test "Docker Image Size" "docker images test-cicd-image --format '{{.Size}}' | grep -E '^[0-9]+[.][0-9]+MB$'" "Docker image size is reasonable"

# Test 5: Canary Deployment Configuration
echo -e "\n${PURPLE}TESTING CANARY DEPLOYMENT${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Canary Deployment File" "test -f application/k8s-manifests/canary-deployment.yaml" "Canary deployment manifest exists"
run_test "Canary Service File" "test -f application/k8s-manifests/canary-service.yaml" "Canary service manifest exists"
run_test "Canary Traffic Routing" "grep -q 'canary' application/k8s-manifests/canary-deployment.yaml" "Canary deployment has proper labels"

# Test 6: Production Deployment Configuration
echo -e "\n${PURPLE}TESTING PRODUCTION DEPLOYMENT${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Production Deployment File" "test -f application/k8s-manifests/deployment.yaml" "Production deployment manifest exists"
run_test "Production Service File" "test -f application/k8s-manifests/service.yaml" "Production service manifest exists"
run_test "Production Ingress File" "test -f application/k8s-manifests/ingress.yaml" "Production ingress manifest exists"

# Test 7: Rollback Strategy
echo -e "\n${PURPLE}TESTING ROLLBACK STRATEGY${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Rollback Job Configuration" "yq eval '.jobs.rollback.if' application/.github/workflows/ci-cd.yml | grep -q 'failure'" "Rollback triggers on failure"
run_test "Rollback Commands" "yq eval '.jobs.rollback.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'rollout undo'" "Rollback uses kubectl rollout undo"

# Test 8: Security Scanning
echo -e "\n${PURPLE}TESTING SECURITY SCANNING${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Trivy Security Scan" "yq eval '.jobs.test.steps[].uses' application/.github/workflows/ci-cd.yml | grep -q 'trivy'" "Trivy security scanning is configured"
run_test "SARIF Output" "yq eval '.jobs.test.steps[].with.format' application/.github/workflows/ci-cd.yml | grep -q 'sarif'" "Security scan outputs SARIF format"

# Test 9: Multi-Cluster Deployment
echo -e "\n${PURPLE}TESTING MULTI-CLUSTER DEPLOYMENT${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Primary Cluster Deployment" "yq eval '.jobs.deploy-production.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'golang-ha-primary'" "Primary cluster deployment configured"
run_test "Secondary Cluster Deployment" "yq eval '.jobs.deploy-production.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'golang-ha-secondary'" "Secondary cluster deployment configured"

# Test 10: Environment Variables and Secrets
echo -e "\n${PURPLE}TESTING ENVIRONMENT CONFIGURATION${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "GCP Authentication" "yq eval '.jobs.build.steps[].uses' application/.github/workflows/ci-cd.yml | grep -q 'google-github-actions/auth'" "GCP authentication configured"
run_test "GCR Configuration" "yq eval '.jobs.build.steps[].run' application/.github/workflows/ci-cd.yml | grep -q 'configure-docker'" "GCR Docker configuration present"

# Test 11: Pipeline Dependencies
echo -e "\n${PURPLE}TESTING PIPELINE DEPENDENCIES${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Build Depends on Test" "yq eval '.jobs.build.needs' application/.github/workflows/ci-cd.yml | grep -q 'test'" "Build job depends on test job"
run_test "Canary Depends on Build" "yq eval '.jobs.deploy-canary.needs' application/.github/workflows/ci-cd.yml | grep -q 'build'" "Canary job depends on build job"
run_test "Production Depends on Canary" "yq eval '.jobs.deploy-production.needs' application/.github/workflows/ci-cd.yml | grep -q 'deploy-canary'" "Production job depends on canary job"

# Test 12: Testing Scripts
echo -e "\n${PURPLE}TESTING TESTING SCRIPTS${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Canary Test Script" "test -f application/scripts/test-canary.sh" "Canary test script exists"
run_test "Production Test Script" "test -f application/scripts/test-production.sh" "Production test script exists"

# Test 13: SSL/TLS Configuration
echo -e "\n${PURPLE}TESTING SSL/TLS CONFIGURATION${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "HTTPS Ingress" "grep -q 'tls:' application/k8s-manifests/ingress.yaml" "Ingress has TLS configuration"
run_test "SSL Certificate" "grep -q 'secretName:' application/k8s-manifests/ingress.yaml" "SSL certificate secret configured"

# Test 14: Monitoring Integration
echo -e "\n${PURPLE}TESTING MONITORING INTEGRATION${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Metrics Endpoint" "grep -q '/metrics' application/golang-server/main.go" "Application exposes metrics endpoint"
run_test "Health Check Endpoint" "grep -q '/health' application/golang-server/main.go" "Application exposes health check endpoint"

# Cleanup
info "Cleaning up test artifacts..."
cd application/golang-server
rm -f test-binary
docker rmi test-cicd-image >/dev/null 2>&1 || true
cd ../..

# Summary
echo -e "\n${PURPLE}CI/CD PIPELINE TEST SUMMARY${NC}"
echo "══════════════════════════════════════════════════════════════"
echo -e "Total Tests: ${TESTS_TOTAL}"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}ALL CI/CD PIPELINE TESTS PASSED!${NC}"
    echo -e "${GREEN}CI/CD pipeline is properly configured for production deployment.${NC}"
    echo ""
    echo -e "${CYAN}GitHub Actions: Configured with all required jobs${NC}"
    echo -e "${CYAN}Docker Build: Multi-stage, secure, optimized${NC}"
    echo -e "${CYAN}Canary Deployment: Traffic routing configured${NC}"
    echo -e "${CYAN}Rollback Strategy: Automated failure recovery${NC}"
    echo -e "${CYAN}Security Scanning: Trivy integration active${NC}"
    echo -e "${CYAN}Multi-Cluster: Primary and secondary deployment${NC}"
    echo -e "${CYAN}SSL/TLS: HTTPS with certificate management${NC}"
    echo ""
    echo -e "${GREEN}Ready for automated CI/CD deployment!${NC}"
    exit 0
else
    echo -e "\n${RED}Some CI/CD pipeline tests failed. Review configuration before deployment.${NC}"
    exit 1
fi
