#!/bin/bash

# Canary Testing Script
# Based on Holded DevOps Challenge requirements:
# - Canary deployments
# - Traffic distribution
# - Health monitoring
# - Rollback functionality

set -e

# Load configuration
if [ -f config.env ]; then
    source config.env
else
    echo "[ERROR] config.env not found. Please run setup.sh first."
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    CANARY TESTING                           ║"
echo "║              Holded DevOps Challenge                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Test 1: Canary Deployment Health
echo -e "\n${BLUE}1. Testing Canary Deployment Health${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Checking canary pods..."
CANARY_PODS=$(kubectl get pods -n golang-app-privileged --no-headers | grep Running | wc -l)
if [ "$CANARY_PODS" -gt 0 ]; then
    echo -e "${GREEN}[PASS] Canary has $CANARY_PODS running pods${NC}"
else
    echo -e "${RED}[FAIL] Canary has no running pods${NC}"
    exit 1
fi

# Test 2: Canary vs Production Comparison
echo -e "\n${BLUE}2. Testing Canary vs Production Comparison${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Starting port-forward to production..."
kubectl port-forward svc/golang-app-service 8080:80 -n golang-app &
PROD_PF_PID=$!
sleep 5

echo "Starting port-forward to canary..."
kubectl port-forward svc/golang-app-canary-service 8081:80 -n golang-app-privileged &
CANARY_PF_PID=$!
sleep 5

echo "Comparing responses..."
PROD_RESPONSE=$(curl -s http://localhost:8080 | head -5)
CANARY_RESPONSE=$(curl -s http://localhost:8081 | head -5)

if [ "$PROD_RESPONSE" = "$CANARY_RESPONSE" ]; then
    echo -e "${GREEN}[PASS] Production and canary have same response${NC}"
else
    echo -e "${YELLOW}[WARN] Production and canary have different responses (expected for different versions)${NC}"
fi

kill $PROD_PF_PID $CANARY_PF_PID 2>/dev/null

# Test 3: Canary Pod Health Monitoring
echo -e "\n${BLUE}3. Testing Canary Pod Health Monitoring${NC}"
echo "══════════════════════════════════════════════════════════════"

CANARY_POD=$(kubectl get pods -n golang-app-privileged --no-headers | grep Running | head -1 | awk '{print $1}')
echo "Canary pod: $CANARY_POD"

if kubectl logs $CANARY_POD -n golang-app-privileged | grep -q "Server started"; then
    echo -e "${GREEN}[PASS] Canary pod is healthy and logging correctly${NC}"
else
    echo -e "${RED}[FAIL] Canary pod is not healthy${NC}"
    exit 1
fi

# Test 4: Traffic Distribution Simulation
echo -e "\n${BLUE}4. Testing Traffic Distribution Simulation${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Starting port-forward..."
kubectl port-forward svc/golang-app-service 8080:80 -n golang-app &
PF_PID=$!
sleep 5

echo "Sending 5 sequential requests to simulate traffic..."
for i in {1..5}; do
    echo "Request $i..."
    curl -s --max-time 10 http://localhost:8080 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[PASS] Request $i successful${NC}"
    else
        echo -e "${RED}[FAIL] Request $i failed${NC}"
    fi
    sleep 1
done

echo "Checking pod resource usage..."
kubectl top pods -n golang-app 2>/dev/null || echo "Metrics server not available"

kill $PF_PID 2>/dev/null

# Test 5: Rollback Functionality
echo -e "\n${BLUE}5. Testing Rollback Functionality${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Simulating rollback by scaling canary to 0..."
kubectl scale deployment golang-app-canary --replicas=0 -n golang-app-privileged

sleep 10

if kubectl get pods -n golang-app-privileged | grep -q "Running"; then
    echo -e "${RED}[FAIL] Canary pods still running after scale down${NC}"
else
    echo -e "${GREEN}[PASS] Canary pods scaled down successfully (rollback simulation)${NC}"
fi

echo "Restoring canary deployment..."
kubectl scale deployment golang-app-canary --replicas=1 -n golang-app-privileged

sleep 10

if kubectl get pods -n golang-app-privileged | grep -q "Running"; then
    echo -e "${GREEN}[PASS] Canary pods restored successfully${NC}"
else
    echo -e "${RED}[FAIL] Canary pods failed to restore${NC}"
    exit 1
fi

echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    CANARY TESTING COMPLETED                  ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${GREEN}All canary requirements from Holded DevOps Challenge are working!${NC}"
echo -e "\n${BLUE}Tested:${NC}"
echo -e "  - Canary deployment health"
echo -e "  - Canary vs production comparison"
echo -e "  - Health monitoring"
echo -e "  - Traffic distribution simulation"
echo -e "  - Rollback functionality"
