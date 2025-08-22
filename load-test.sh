#!/bin/bash

# Load Testing Script
# Tests application performance and auto-scaling capabilities
# Based on Holded DevOps Challenge requirements

set -e

# Configuration
PROJECT_ID="peak-tide-469522-r7"
PRIMARY_CLUSTER="golang-ha-primary"
PRIMARY_REGION="europe-west1"
TEST_DURATION=300  # 5 minutes
CONCURRENT_USERS=50
REQUESTS_PER_SECOND=100

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
echo "║                    LOAD TESTING                             ║"
echo "║                Golang HA Application Performance            ║"
echo "║              Based on Holded DevOps Challenge               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check prerequisites
log "Checking prerequisites..."

# Check if hey is installed
if ! command -v hey &> /dev/null; then
    warning "hey tool not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install hey
    else
        echo "Please install hey tool: https://github.com/rakyll/hey"
        exit 1
    fi
fi

# Get cluster credentials
log "Getting cluster credentials..."
gcloud container clusters get-credentials $PRIMARY_CLUSTER --region=$PRIMARY_REGION --project=$PROJECT_ID

# Start port-forward
log "Starting port-forward..."
kubectl port-forward service/golang-app-service 8080:80 -n golang-app >/dev/null 2>&1 &
PF_PID=$!
sleep 5

# Function to get current pod count
get_pod_count() {
    kubectl get pods -n golang-app --no-headers | grep -c 'Running'
}

# Function to get CPU usage
get_cpu_usage() {
    kubectl top pods -n golang-app --no-headers | awk '{sum+=$2} END {print sum}'
}

# Function to get memory usage
get_memory_usage() {
    kubectl top pods -n golang-app --no-headers | awk '{sum+=$3} END {print sum}'
}

# Baseline measurements
log "Taking baseline measurements..."
BASELINE_PODS=$(get_pod_count)
BASELINE_CPU=$(get_cpu_usage)
BASELINE_MEMORY=$(get_memory_usage)

info "Baseline - Pods: $BASELINE_PODS, CPU: ${BASELINE_CPU}m, Memory: ${BASELINE_MEMORY}Mi"

# Test 1: Light Load Test
echo -e "\n${PURPLE}LIGHT LOAD TEST${NC}"
echo "══════════════════════════════════════════════════════════════"

log "Running light load test (10 users, 30 seconds)..."
hey -z 30s -c 10 http://localhost:8080/ > light_load_results.txt 2>&1

LIGHT_REQUESTS=$(grep "Total:" light_load_results.txt | awk '{print $2}')
LIGHT_SUCCESS_RATE=$(grep "Success rate:" light_load_results.txt | awk '{print $3}' | sed 's/%//')

success "Light Load - Requests: $LIGHT_REQUESTS, Success Rate: ${LIGHT_SUCCESS_RATE}%"

# Test 2: Medium Load Test
echo -e "\n${PURPLE}MEDIUM LOAD TEST${NC}"
echo "══════════════════════════════════════════════════════════════"

log "Running medium load test (25 users, 60 seconds)..."
hey -z 60s -c 25 http://localhost:8080/ > medium_load_results.txt 2>&1

MEDIUM_REQUESTS=$(grep "Total:" medium_load_results.txt | awk '{print $2}')
MEDIUM_SUCCESS_RATE=$(grep "Success rate:" medium_load_results.txt | awk '{print $3}' | sed 's/%//')

success "Medium Load - Requests: $MEDIUM_REQUESTS, Success Rate: ${MEDIUM_SUCCESS_RATE}%"

# Test 3: High Load Test
echo -e "\n${PURPLE}HIGH LOAD TEST${NC}"
echo "══════════════════════════════════════════════════════════════"

log "Running high load test (50 users, 120 seconds)..."
hey -z 120s -c 50 http://localhost:8080/ > high_load_results.txt 2>&1

HIGH_REQUESTS=$(grep "Total:" high_load_results.txt | awk '{print $2}')
HIGH_SUCCESS_RATE=$(grep "Success rate:" high_load_results.txt | awk '{print $3}' | sed 's/%//')

success "High Load - Requests: $HIGH_REQUESTS, Success Rate: ${HIGH_SUCCESS_RATE}%"

# Test 4: Stress Test
echo -e "\n${PURPLE}STRESS TEST${NC}"
echo "══════════════════════════════════════════════════════════════"

log "Running stress test (100 users, 180 seconds)..."
hey -z 180s -c 100 http://localhost:8080/ > stress_load_results.txt 2>&1

STRESS_REQUESTS=$(grep "Total:" stress_load_results.txt | awk '{print $2}')
STRESS_SUCCESS_RATE=$(grep "Success rate:" stress_load_results.txt | awk '{print $3}' | sed 's/%//')

success "Stress Load - Requests: $STRESS_REQUESTS, Success Rate: ${STRESS_SUCCESS_RATE}%"

# Check auto-scaling
echo -e "\n${PURPLE}📈 AUTO-SCALING ANALYSIS${NC}"
echo "══════════════════════════════════════════════════════════════"

FINAL_PODS=$(get_pod_count)
FINAL_CPU=$(get_cpu_usage)
FINAL_MEMORY=$(get_memory_usage)

info "Final - Pods: $FINAL_PODS, CPU: ${FINAL_CPU}m, Memory: ${FINAL_MEMORY}Mi"

POD_SCALING=$((FINAL_PODS - BASELINE_PODS))
CPU_INCREASE=$((FINAL_CPU - BASELINE_CPU))
MEMORY_INCREASE=$((FINAL_MEMORY - BASELINE_MEMORY))

if [ $POD_SCALING -gt 0 ]; then
    success "Auto-scaling triggered: +$POD_SCALING pods"
else
    warning "No auto-scaling detected"
fi

# Performance Analysis
echo -e "\n${PURPLE}PERFORMANCE ANALYSIS${NC}"
echo "══════════════════════════════════════════════════════════════"

# Calculate average response time
LIGHT_AVG=$(grep "Average:" light_load_results.txt | awk '{print $2}')
MEDIUM_AVG=$(grep "Average:" medium_load_results.txt | awk '{print $2}')
HIGH_AVG=$(grep "Average:" high_load_results.txt | awk '{print $2}')
STRESS_AVG=$(grep "Average:" stress_load_results.txt | awk '{print $2}')

echo "Response Times:"
echo "  Light Load: ${LIGHT_AVG}ms"
echo "  Medium Load: ${MEDIUM_AVG}ms"
echo "  High Load: ${HIGH_AVG}ms"
echo "  Stress Load: ${STRESS_AVG}ms"

# Check HPA status
echo -e "\n${PURPLE}HPA STATUS${NC}"
echo "══════════════════════════════════════════════════════════════"

kubectl get hpa -n golang-app

# Check resource usage
echo -e "\n${PURPLE}💾 RESOURCE USAGE${NC}"
echo "══════════════════════════════════════════════════════════════"

kubectl top pods -n golang-app

# Cleanup
log "Cleaning up..."
kill $PF_PID 2>/dev/null || true
rm -f *_load_results.txt

# Summary
echo -e "\n${PURPLE}LOAD TEST SUMMARY${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Test Results:"
echo "  Light Load: ${LIGHT_SUCCESS_RATE}% success rate"
echo "  Medium Load: ${MEDIUM_SUCCESS_RATE}% success rate"
echo "  High Load: ${HIGH_SUCCESS_RATE}% success rate"
echo "  Stress Load: ${STRESS_SUCCESS_RATE}% success rate"

echo -e "\nScaling Results:"
echo "  Pod Scaling: +$POD_SCALING pods"
echo "  CPU Increase: +${CPU_INCREASE}m"
echo "  Memory Increase: +${MEMORY_INCREASE}Mi"

# Performance validation
if [ "${LIGHT_SUCCESS_RATE%.*}" -ge 95 ] && [ "${MEDIUM_SUCCESS_RATE%.*}" -ge 90 ] && [ "${HIGH_SUCCESS_RATE%.*}" -ge 85 ]; then
    success "Performance test PASSED - Application handles load well"
    exit 0
else
    failure "Performance test FAILED - Application needs optimization"
    exit 1
fi
