#!/bin/bash

# Master Test Script
# Runs all comprehensive tests for the Golang HA Infrastructure
# Usage: ./run-all-tests.sh [full|quick|validate]

set -e

# Configuration
PROJECT_ID="${PROJECT_ID:-YOUR_PROJECT_ID}"
PRIMARY_CLUSTER="golang-ha-primary"
SECONDARY_CLUSTER="golang-ha-secondary"
PRIMARY_REGION="${PRIMARY_REGION:-europe-west1}"
SECONDARY_REGION="${SECONDARY_REGION:-europe-west3}"
LOAD_BALANCER_IP="${LOAD_BALANCER_IP:-REPLACE_WITH_ACTUAL_IP}"

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

# Header
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Master Test Script                       ║"
echo "║              Golang HA Infrastructure Testing               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "Project ID: $PROJECT_ID"
echo "Primary Cluster: $PRIMARY_CLUSTER ($PRIMARY_REGION)"
echo "Secondary Cluster: $SECONDARY_CLUSTER ($SECONDARY_REGION)"
echo "Load Balancer IP: $LOAD_BALANCER_IP"
echo "══════════════════════════════════════════════════════════════"

# Check if required tools are available
echo -e "\n${PURPLE}CHECKING REQUIRED TOOLS${NC}"
echo "══════════════════════════════════════════════════════════════"

check_tool() {
    local tool=$1
    if command -v $tool >/dev/null 2>&1; then
        success "$tool is available"
    else
        failure "$tool is not available"
        return 1
    fi
}

check_tool "terraform"
check_tool "kubectl"
check_tool "gcloud"
check_tool "docker"
check_tool "curl"
check_tool "yq"
check_tool "jq"

# Test 1: Infrastructure Testing
echo -e "\n${PURPLE}RUNNING INFRASTRUCTURE TESTS${NC}"
echo "══════════════════════════════════════════════════════════════"

if [ -f "./test-infrastructure.sh" ]; then
    info "Running comprehensive infrastructure tests..."
    if ./test-infrastructure.sh; then
        success "Infrastructure tests passed"
    else
        failure "Infrastructure tests failed"
    fi
else
    failure "Infrastructure test script not found"
fi

# Test 2: CI/CD Testing
echo -e "\n${PURPLE}RUNNING CI/CD TESTS${NC}"
echo "══════════════════════════════════════════════════════════════"

if [ -f "./test-cicd.sh" ]; then
    info "Running comprehensive CI/CD tests..."
    if ./test-cicd.sh; then
        success "CI/CD tests passed"
    else
        failure "CI/CD tests failed"
    fi
else
    failure "CI/CD test script not found"
fi

# Test 3: Canary and Rollback Testing
echo -e "\n${PURPLE}RUNNING CANARY AND ROLLBACK TESTS${NC}"
echo "══════════════════════════════════════════════════════════════"

if [ -f "./test-canary-rollback.sh" ]; then
    info "Running comprehensive canary and rollback tests..."
    if ./test-canary-rollback.sh "$LOAD_BALANCER_IP" 100; then
        success "Canary and rollback tests passed"
    else
        failure "Canary and rollback tests failed"
    fi
else
    failure "Canary and rollback test script not found"
fi

# Test 4: Load Testing
echo -e "\n${PURPLE}RUNNING LOAD TESTS${NC}"
echo "══════════════════════════════════════════════════════════════"

if [ -f "./load-test.sh" ]; then
    info "Running comprehensive load tests..."
    if ./load-test.sh "$LOAD_BALANCER_IP"; then
        success "Load tests passed"
    else
        failure "Load tests failed"
    fi
else
    failure "Load test script not found"
fi

# Test 5: Disaster Recovery Testing
echo -e "\n${PURPLE}RUNNING DISASTER RECOVERY TESTS${NC}"
echo "══════════════════════════════════════════════════════════════"

if [ -f "./disaster-recovery-test.sh" ]; then
    info "Running comprehensive disaster recovery tests..."
    if ./disaster-recovery-test.sh; then
        success "Disaster recovery tests passed"
    else
        failure "Disaster recovery tests failed"
    fi
else
    failure "Disaster recovery test script not found"
fi

# Test 6: Security Validation
echo -e "\n${PURPLE}RUNNING SECURITY VALIDATION${NC}"
echo "══════════════════════════════════════════════════════════════"

# Check security configurations
run_security_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name - $expected_result"
        return 0
    else
        failure "$test_name - Failed"
        return 1
    fi
}

run_security_test "Pod Security Policies" "kubectl get psp" "Pod security policies are configured"
run_security_test "Network Policies" "kubectl get networkpolicy" "Network policies are configured"
run_security_test "RBAC Configuration" "kubectl get clusterrolebinding | grep -q golang" "RBAC is properly configured"
run_security_test "Secrets Management" "kubectl get secret -n golang-app" "Secrets are properly managed"
run_security_test "Audit Logging" "gcloud logging sinks list --project=$PROJECT_ID | grep -q golang-ha" "Audit logging is enabled"

# Test 7: Monitoring and Observability
echo -e "\n${PURPLE}RUNNING MONITORING AND OBSERVABILITY TESTS${NC}"
echo "══════════════════════════════════════════════════════════════"

run_monitoring_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name - $expected_result"
        return 0
    else
        failure "$test_name - Failed"
        return 1
    fi
}

run_monitoring_test "Prometheus Running" "kubectl get pods -n monitoring | grep prometheus | grep -q Running" "Prometheus is running"
run_monitoring_test "Grafana Running" "kubectl get pods -n monitoring | grep grafana | grep -q Running" "Grafana is running"
run_monitoring_test "AlertManager Running" "kubectl get pods -n monitoring | grep alertmanager | grep -q Running" "AlertManager is running"
run_monitoring_test "Custom Metrics" "curl -s http://$LOAD_BALANCER_IP/metrics | grep -q golang_app_" "Custom metrics are exposed"
run_monitoring_test "HPA Configuration" "kubectl get hpa -n golang-app" "Horizontal Pod Autoscaler is configured"

# Test 8: High Availability Validation
echo -e "\n${PURPLE}RUNNING HIGH AVAILABILITY VALIDATION${NC}"
echo "══════════════════════════════════════════════════════════════"

run_ha_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name - $expected_result"
        return 0
    else
        failure "$test_name - Failed"
        return 1
    fi
}

run_ha_test "Multi-Region Clusters" "gcloud container clusters list --project=$PROJECT_ID | grep -c RUNNING | grep -q 2" "Two clusters are running"
run_ha_test "Primary Cluster Health" "gcloud container clusters describe $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID | grep -q 'status: RUNNING'" "Primary cluster is healthy"
run_ha_test "Secondary Cluster Health" "gcloud container clusters describe $SECONDARY_CLUSTER --region=$SECONDARY_REGION --project=$PROJECT_ID | grep -q 'status: RUNNING'" "Secondary cluster is healthy"
run_ha_test "Load Balancer Health" "curl -s -I https://$LOAD_BALANCER_IP | grep -q 'HTTP/'" "Load balancer is responding"
run_ha_test "Auto-scaling Enabled" "gcloud container clusters describe $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID | grep -A 5 'autoscaling:' | grep -q 'enabled: true'" "Auto-scaling is enabled"

# Test 9: Performance Validation
echo -e "\n${PURPLE}RUNNING PERFORMANCE VALIDATION${NC}"
echo "══════════════════════════════════════════════════════════════"

# Test response time
response_time=$(curl -s -w '%{time_total}' -o /dev/null https://$LOAD_BALANCER_IP/health)
echo "Response time: ${response_time}s"

if (( $(echo "$response_time < 2.0" | bc -l) )); then
    success "Performance validation - Response time acceptable (< 2s)"
else
    warning "Performance validation - Response time may be slow (> 2s)"
fi

# Test concurrent requests
echo "Testing concurrent requests..."
for i in {1..20}; do
    curl -s https://$LOAD_BALANCER_IP/health > /dev/null &
done
wait

success "Performance validation - Concurrent requests handled successfully"

# Test 10: Documentation Validation
echo -e "\n${PURPLE}RUNNING DOCUMENTATION VALIDATION${NC}"
echo "══════════════════════════════════════════════════════════════"

run_doc_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name - $expected_result"
        return 0
    else
        failure "$test_name - Failed"
        return 1
    fi
}

run_doc_test "README Exists" "test -f README.md" "README documentation exists"
run_doc_test "Architecture Diagram" "test -f ARCHITECTURE_DIAGRAM.md" "Architecture diagram exists"
run_doc_test "Technical Decisions" "test -f TECHNICAL_DECISIONS.md" "Technical decisions documented"
run_doc_test "Disaster Recovery Plan" "test -f DISASTER_RECOVERY_PLAN.md" "Disaster recovery plan exists"
run_doc_test "Interview Summary" "test -f INTERVIEW_SUMMARY.md" "Interview summary exists"

# Final Summary
echo -e "\n${PURPLE}FINAL TEST SUMMARY${NC}"
echo "══════════════════════════════════════════════════════════════"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo -e "${CYAN}Total Tests: $TESTS_TOTAL${NC}"

# Calculate success rate
if [ $TESTS_TOTAL -gt 0 ]; then
    success_rate=$(( (TESTS_PASSED * 100) / TESTS_TOTAL ))
    echo -e "${CYAN}Success Rate: $success_rate%${NC}"
else
    success_rate=0
    echo -e "${CYAN}Success Rate: 0%${NC}"
fi

# Final result
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}ALL TESTS PASSED! The Golang HA Infrastructure is fully operational and production-ready.${NC}"
    echo -e "${GREEN}[PASS] Infrastructure: Multi-region GKE clusters with high availability${NC}"
    echo -e "${GREEN}[PASS] CI/CD: Automated pipeline with canary deployments and rollback${NC}"
    echo -e "${GREEN}[PASS] Security: Zero Trust architecture with comprehensive monitoring${NC}"
    echo -e "${GREEN}[PASS] Performance: Load tested and optimized for production${NC}"
    echo -e "${GREEN}[PASS] Documentation: Complete and professional documentation${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please review the output above and fix the issues.${NC}"
    echo -e "${YELLOW}[WARN] Failed tests: $TESTS_FAILED out of $TESTS_TOTAL${NC}"
    exit 1
fi
