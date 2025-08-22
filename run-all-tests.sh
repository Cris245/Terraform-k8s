#!/bin/bash

# Master Test Runner
# Runs all test suites for the Golang HA Infrastructure
# Based on Holded DevOps Challenge requirements

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
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0
TOTAL_TEST_SUITES=0

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
echo "║                    MASTER TEST RUNNER                       ║"
echo "║                Golang HA Infrastructure Validation           ║"
echo "║              Based on Holded DevOps Challenge               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to run a test suite
run_test_suite() {
    local test_name="$1"
    local test_script="$2"
    local description="$3"
    
    echo -e "\n${PURPLE}RUNNING: $test_name${NC}"
    echo "══════════════════════════════════════════════════════════════"
    info "$description"
    echo ""
    
    if [ -f "$test_script" ]; then
        if ./"$test_script"; then
            success "$test_name - PASSED"
            ((TOTAL_TESTS_PASSED++))
        else
            failure "$test_name - FAILED"
            ((TOTAL_TESTS_FAILED++))
        fi
    else
        failure "$test_name - Script not found: $test_script"
        ((TOTAL_TESTS_FAILED++))
    fi
    
    ((TOTAL_TEST_SUITES++))
}

# Check prerequisites
log "Checking test prerequisites..."

# Check if required tools are available
if ! command -v kubectl >/dev/null 2>&1; then
    failure "kubectl is required but not installed"
    exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
    failure "gcloud CLI is required but not installed"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    failure "curl is required but not installed"
    exit 1
fi

success "All prerequisites are satisfied"

# Run test suites
echo -e "\n${PURPLE}EXECUTING TEST SUITES${NC}"
echo "══════════════════════════════════════════════════════════════"

# Test Suite 1: Deployment Validation
run_test_suite \
    "Deployment Validation" \
    "test-deployment.sh" \
    "Validates infrastructure, application deployment, monitoring, security, and high availability"

# Test Suite 2: Load Testing
run_test_suite \
    "Load Testing" \
    "load-test.sh" \
    "Tests application performance, auto-scaling, and response times under various load conditions"

# Test Suite 3: Disaster Recovery
run_test_suite \
    "Disaster Recovery" \
    "disaster-recovery-test.sh" \
    "Tests failover capabilities, RTO/RPO compliance, and cross-region recovery"

# Summary
echo -e "\n${PURPLE}MASTER TEST SUMMARY${NC}"
echo "══════════════════════════════════════════════════════════════"
echo -e "Total Test Suites: ${TOTAL_TEST_SUITES}"
echo -e "Passed: ${GREEN}${TOTAL_TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TOTAL_TESTS_FAILED}${NC}"

# Final result
if [ $TOTAL_TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}ALL TEST SUITES PASSED!${NC}"
    echo -e "${GREEN}The Golang HA Infrastructure is fully operational and meets all requirements.${NC}"
    echo ""
    echo -e "${CYAN}Infrastructure: Deployed and validated${NC}"
    echo -e "${CYAN}Application: Running and healthy${NC}"
    echo -e "${CYAN}Monitoring: Operational${NC}"
    echo -e "${CYAN}Security: Configured and tested${NC}"
    echo -e "${CYAN}High Availability: Verified${NC}"
    echo -e "${CYAN}Performance: Tested and optimized${NC}"
    echo -e "${CYAN}Disaster Recovery: Validated${NC}"
    echo ""
    echo -e "${GREEN}Ready for production deployment.${NC}"
    exit 0
else
    echo -e "\n${RED}SOME TEST SUITES FAILED${NC}"
    echo -e "${RED}Please review the failed tests and fix the issues before proceeding.${NC}"
    exit 1
fi
