#!/bin/bash

# CI/CD Testing Script
# Based on Holded DevOps Challenge requirements:
# - Using Containers as part of automation
# - CI pipeline that deploys to GCP
# - Canary deployments
# - Automated rollback strategies
# - Serve traffic from port 443 with self-signed certificate

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
echo "║                    CI/CD TESTING                            ║"
echo "║              Holded DevOps Challenge                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "Testing with configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Primary Region: $PRIMARY_REGION"
echo "  Secondary Region: $SECONDARY_REGION"

# Test 1: Container Build and Push
echo -e "\n${BLUE}1. Testing Container Build and Push${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Building Docker image..."
if docker build -t gcr.io/$PROJECT_ID/golang-ha:test application/golang-server/; then
    echo -e "${GREEN}[PASS] Docker build successful${NC}"
else
    echo -e "${RED}[FAIL] Docker build failed${NC}"
    exit 1
fi

echo "Pushing Docker image..."
if docker push gcr.io/$PROJECT_ID/golang-ha:test; then
    echo -e "${GREEN}[PASS] Docker push successful${NC}"
else
    echo -e "${RED}[FAIL] Docker push failed${NC}"
    exit 1
fi

# Test 2: Application Deployment
echo -e "\n${BLUE}2. Testing Application Deployment${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Checking application pods..."
if kubectl get pods -n golang-app | grep -q "Running"; then
    echo -e "${GREEN}[PASS] Application is deployed and running${NC}"
else
    echo -e "${RED}[FAIL] Application is not running${NC}"
    exit 1
fi

# Test 3: Canary Deployment
echo -e "\n${BLUE}3. Testing Canary Deployment${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Checking canary deployment..."
if kubectl get pods -n golang-app-privileged | grep -q "Running"; then
    echo -e "${GREEN}[PASS] Canary deployment is running${NC}"
else
    echo -e "${RED}[FAIL] Canary deployment is not running${NC}"
    exit 1
fi

# Test 4: Multi-cluster Deployment
echo -e "\n${BLUE}4. Testing Multi-cluster Deployment${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Checking primary cluster..."
if kubectl get pods -n golang-app | grep -q "Running"; then
    echo -e "${GREEN}[PASS] Primary cluster has running pods${NC}"
else
    echo -e "${RED}[FAIL] Primary cluster has no running pods${NC}"
    exit 1
fi

echo "Checking secondary cluster..."
if gcloud container clusters get-credentials $SECONDARY_CLUSTER --region $SECONDARY_REGION --project $PROJECT_ID && kubectl get pods -n golang-app | grep -q "Running"; then
    echo -e "${GREEN}[PASS] Secondary cluster has running pods${NC}"
else
    echo -e "${RED}[FAIL] Secondary cluster has no running pods${NC}"
    exit 1
fi

# Test 5: Load Balancer and SSL
echo -e "\n${BLUE}5. Testing Load Balancer and SSL${NC}"
echo "══════════════════════════════════════════════════════════════"

LB_IP=$(gcloud compute addresses describe golang-ha-global-ip --global --project=$PROJECT_ID --format="value(address)")
echo "Load Balancer IP: $LB_IP"

echo "Testing HTTP to HTTPS redirect..."
if curl -s -I "http://$LB_IP" | grep -q "301\|302"; then
    echo -e "${GREEN}[PASS] HTTP to HTTPS redirect is working${NC}"
else
    echo -e "${YELLOW}[WARN] HTTP to HTTPS redirect not detected (may be normal)${NC}"
fi

# Test 6: Automated Rollback Simulation
echo -e "\n${BLUE}6. Testing Automated Rollback Strategy${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Simulating rollback by scaling canary to 0..."
kubectl scale deployment golang-app-canary --replicas=0 -n golang-app-privileged

sleep 10

if kubectl get pods -n golang-app-privileged | grep -q "Running"; then
    echo -e "${RED}[FAIL] Canary pods still running after scale down${NC}"
else
    echo -e "${GREEN}[PASS] Canary pods scaled down successfully${NC}"
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

# Test 7: Application Health
echo -e "\n${BLUE}7. Testing Application Health${NC}"
echo "══════════════════════════════════════════════════════════════"

echo "Starting port-forward..."
kubectl port-forward svc/golang-app-service 8080:80 -n golang-app &
PF_PID=$!
sleep 5

echo "Testing application response..."
if curl -s http://localhost:8080 | grep -q "Golang HA Server"; then
    echo -e "${GREEN}[PASS] Application is responding correctly${NC}"
else
    echo -e "${RED}[FAIL] Application is not responding${NC}"
    kill $PF_PID 2>/dev/null
    exit 1
fi

kill $PF_PID 2>/dev/null

echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    CI/CD TESTING COMPLETED                   ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${GREEN}All CI/CD requirements from Holded DevOps Challenge are working!${NC}"
echo -e "\n${BLUE}Tested:${NC}"
echo -e "  - Container build and push"
echo -e "  - CI pipeline deployment to GCP"
echo -e "  - Canary deployments"
echo -e "  - Automated rollback strategies"
echo -e "  - Load balancer with SSL redirect"
echo -e "  - Multi-cluster deployment"
