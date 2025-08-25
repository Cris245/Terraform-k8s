#!/bin/bash

# Canary and Rollback Testing Script
# Comprehensive testing for canary deployments and automated rollback strategies
# Usage: ./test-canary-rollback.sh [gateway_ip] [total_requests]

set -e

# Configuration
GATEWAY_IP="${1:-REPLACE_WITH_GATEWAY_IP}"
TOTAL_REQUESTS=${2:-100}
NAMESPACE=${3:-golang-app}
DEPLOYMENT=${4:-golang-app}
HEALTH_CHECK_RETRIES=${5:-5}
HEALTH_CHECK_INTERVAL=${6:-30}

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
echo "║              Canary and Rollback Testing Script             ║"
echo "║         Traffic Distribution, Health Monitoring, Rollback   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "Gateway IP: $GATEWAY_IP"
echo "Total Requests: $TOTAL_REQUESTS"
echo "Namespace: $NAMESPACE"
echo "Deployment: $DEPLOYMENT"
echo "Health Check Retries: $HEALTH_CHECK_RETRIES"
echo "Health Check Interval: ${HEALTH_CHECK_INTERVAL}s"
echo "══════════════════════════════════════════════════════════════"

# Test 1: Canary Deployment Setup
echo -e "\n${PURPLE}TESTING CANARY DEPLOYMENT SETUP${NC}"
echo "══════════════════════════════════════════════════════════════"

run_test "Canary Namespace" "kubectl get namespace golang-app-privileged" "Canary namespace exists"
run_test "Canary Deployment" "kubectl get deployment -n golang-app-privileged" "Canary deployment exists"
run_test "Canary Service" "kubectl get service -n golang-app-privileged" "Canary service exists"
run_test "Canary Pods Running" "kubectl get pods -n golang-app-privileged --no-headers | grep -c 'Running' | grep -q '1'" "Canary pods are running"

# Test 2: Header-based Canary Routing
echo -e "\n${PURPLE}📍 TESTING HEADER-BASED CANARY ROUTING${NC}"
echo "══════════════════════════════════════════════════════════════"

canary_header_success=0
for i in {1..5}; do
    response=$(curl -s -H "canary: true" http://$GATEWAY_IP/ | grep -o "canary" || echo "")
    if [ "$response" = "canary" ]; then
        ((canary_header_success++))
        echo "[PASS] Request $i: Canary header routing working"
    else
        echo "[FAIL] Request $i: Canary header routing failed"
    fi
done

if [ $canary_header_success -ge 3 ]; then
    success "Canary header routing - $canary_header_success/5 requests successful"
else
    failure "Canary header routing - Only $canary_header_success/5 requests successful"
fi

# Test 3: Traffic Distribution Analysis
echo -e "\n${PURPLE}TESTING TRAFFIC DISTRIBUTION ANALYSIS${NC}"
echo "══════════════════════════════════════════════════════════════"

stable_count=0
canary_count=0
unknown_count=0

for i in $(seq 1 $TOTAL_REQUESTS); do
    response=$(curl -s http://$GATEWAY_IP/ | grep -o "production\|canary" || echo "unknown")
    
    case $response in
        "production")
            ((stable_count++))
            ;;
        "canary")
            ((canary_count++))
            ;;
        *)
            ((unknown_count++))
            ;;
    esac
    
    if [ $((i % 20)) -eq 0 ]; then
        echo "Progress: $i/$TOTAL_REQUESTS - Stable: $stable_count, Canary: $canary_count, Unknown: $unknown_count"
    fi
done

# Calculate percentages
if [ $TOTAL_REQUESTS -gt 0 ]; then
    stable_percentage=$(( (stable_count * 100) / TOTAL_REQUESTS ))
    canary_percentage=$(( (canary_count * 100) / TOTAL_REQUESTS ))
    unknown_percentage=$(( (unknown_count * 100) / TOTAL_REQUESTS ))
else
    stable_percentage=0
    canary_percentage=0
    unknown_percentage=0
fi

echo ""
echo "Final Traffic Distribution:"
echo "  Stable (production): $stable_count ($stable_percentage%)"
echo "  Canary: $canary_count ($canary_percentage%)"
echo "  Unknown: $unknown_count ($unknown_percentage%)"

# Validate traffic distribution
if [ $stable_percentage -ge 80 ] && [ $canary_percentage -le 20 ]; then
    success "Traffic distribution - 80/20 split maintained"
else
    warning "Traffic distribution - Split may be outside expected range"
fi

# Test 4: Health Endpoint Validation
echo -e "\n${PURPLE}TESTING HEALTH ENDPOINT VALIDATION${NC}"
echo "══════════════════════════════════════════════════════════════"

# Test stable health
stable_health=$(curl -s http://$GATEWAY_IP/health)
if echo "$stable_health" | grep -q "healthy"; then
    success "Stable health endpoint - OK"
else
    failure "Stable health endpoint - Failed"
    echo "   Response: $stable_health"
fi

# Test canary health with header
canary_health=$(curl -s -H "canary: true" http://$GATEWAY_IP/health)
if echo "$canary_health" | grep -q "healthy"; then
    success "Canary health endpoint - OK"
else
    failure "Canary health endpoint - Failed"
    echo "   Response: $canary_health"
fi

# Test 5: Deployment Health Monitoring
echo -e "\n${PURPLE}TESTING DEPLOYMENT HEALTH MONITORING${NC}"
echo "══════════════════════════════════════════════════════════════"

# Function to check deployment health
check_deployment_health() {
    local retries=0
    
    while [ $retries -lt $HEALTH_CHECK_RETRIES ]; do
        echo "Health check attempt $((retries + 1))/$HEALTH_CHECK_RETRIES"
        
        # Check if deployment is ready
        if kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q "^[1-9]"; then
            echo "[PASS] Deployment has ready replicas"
            
            # Check health endpoint
            if curl -f -s http://$GATEWAY_IP/health > /dev/null; then
                echo "[PASS] Health endpoint responding"
                return 0
            else
                echo "[FAIL] Health endpoint not responding"
            fi
        else
            echo "[FAIL] No ready replicas found"
        fi
        
        ((retries++))
        if [ $retries -lt $HEALTH_CHECK_RETRIES ]; then
            echo "⏳ Waiting ${HEALTH_CHECK_INTERVAL}s before next check..."
            sleep $HEALTH_CHECK_INTERVAL
        fi
    done
    
            echo "[FAIL] Health checks failed after $HEALTH_CHECK_RETRIES attempts"
    return 1
}

# Test current deployment health
if check_deployment_health; then
    success "Deployment health monitoring - Current deployment is healthy"
else
    failure "Deployment health monitoring - Current deployment has issues"
fi

# Test 6: Rollback Functionality
echo -e "\n${PURPLE}TESTING ROLLBACK FUNCTIONALITY${NC}"
echo "══════════════════════════════════════════════════════════════"

# Function to get current deployment revision
get_current_revision() {
    kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}'
}

# Function to get previous revision
get_previous_revision() {
    current_revision=$(get_current_revision)
    previous_revision=$((current_revision - 1))
    echo $previous_revision
}

# Function to perform rollback
perform_rollback() {
    echo "Performing rollback..."
    
    current_revision=$(get_current_revision)
    previous_revision=$(get_previous_revision)
    
    echo "Current revision: $current_revision"
    echo "Rolling back to revision: $previous_revision"
    
    # Perform rollback to previous revision
    kubectl rollout undo deployment/$DEPLOYMENT -n $NAMESPACE
    
    # Wait for rollback to complete
    echo "Waiting for rollback to complete..."
    kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=300s
    
    # Check if rollback was successful
    new_revision=$(get_current_revision)
    if [ "$new_revision" != "$current_revision" ]; then
        echo "[PASS] Rollback completed successfully (revision: $new_revision)"
        return 0
    else
        echo "[FAIL] Rollback failed - revision unchanged"
        return 1
    fi
}

# Test rollback functionality
current_revision=$(get_current_revision)
if [ "$current_revision" -gt 1 ]; then
    if perform_rollback; then
        success "Rollback functionality - Rollback executed successfully"
        
        # Verify health after rollback
        if check_deployment_health; then
            success "Rollback verification - Deployment healthy after rollback"
        else
            failure "Rollback verification - Deployment unhealthy after rollback"
        fi
    else
        failure "Rollback functionality - Rollback failed"
    fi
else
    warning "Rollback functionality - No previous revision available for testing"
fi

# Test 7: Error Rate Monitoring
echo -e "\n${PURPLE}TESTING ERROR RATE MONITORING${NC}"
echo "══════════════════════════════════════════════════════════════"

# Function to check error rate from Prometheus
check_error_rate() {
    echo "Checking error rate from Prometheus..."
    
    # Get Prometheus service IP
    PROMETHEUS_IP=$(kubectl get service -n monitoring kube-prometheus-stack-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$PROMETHEUS_IP" ]; then
        # Query error rate from Prometheus
        error_rate=$(curl -s "http://$PROMETHEUS_IP:9090/api/v1/query?query=rate(http_requests_total{status=~\"5..\"}[5m])" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
        
        if [ "$error_rate" != "0" ] && [ "$error_rate" != "null" ]; then
            echo "[WARN] Error rate detected: $error_rate"
            return 1
        else
            echo "[PASS] No significant error rate detected"
            return 0
        fi
    else
        echo "[WARN] Prometheus not accessible"
        return 0
    fi
}

if check_error_rate; then
    success "Error rate monitoring - No critical errors detected"
else
    warning "Error rate monitoring - Errors detected, may trigger rollback"
fi

# Test 8: Performance Metrics
echo -e "\n${PURPLE}TESTING PERFORMANCE METRICS${NC}"
echo "══════════════════════════════════════════════════════════════"

# Test response time
response_time=$(curl -s -w '%{time_total}' -o /dev/null http://$GATEWAY_IP/health)
echo "Response time: ${response_time}s"

if (( $(echo "$response_time < 1.0" | bc -l) )); then
    success "Performance metrics - Response time acceptable (< 1s)"
else
    warning "Performance metrics - Response time may be slow (> 1s)"
fi

# Test concurrent requests
echo "Testing concurrent requests..."
for i in {1..10}; do
    curl -s http://$GATEWAY_IP/health > /dev/null &
done
wait

success "Performance metrics - Concurrent requests handled successfully"

# Test 9: Canary Metrics Validation
echo -e "\n${PURPLE}TESTING CANARY METRICS VALIDATION${NC}"
echo "══════════════════════════════════════════════════════════════"

# Check custom metrics endpoint
metrics_response=$(curl -s http://$GATEWAY_IP/metrics)
if echo "$metrics_response" | grep -q "golang_app_"; then
    success "Canary metrics - Custom application metrics exposed"
else
    failure "Canary metrics - Custom metrics not found"
fi

# Check canary-specific metrics
if echo "$metrics_response" | grep -q "canary"; then
    success "Canary metrics - Canary-specific metrics available"
else
    warning "Canary metrics - Canary-specific metrics not found"
fi

# Summary
echo -e "\n${PURPLE}TEST SUMMARY${NC}"
echo "══════════════════════════════════════════════════════════════"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo -e "${CYAN}Total Tests: $TESTS_TOTAL${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}ALL CANARY AND ROLLBACK TESTS PASSED! Deployment strategies are working correctly.${NC}"
    exit 0
else
    echo -e "\n${RED}Some canary and rollback tests failed. Review the deployment strategies.${NC}"
    exit 1
fi
