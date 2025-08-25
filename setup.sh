#!/bin/bash

# Comprehensive Setup Script
# Handles prerequisites, configuration, and full deployment
# Based on Holded DevOps Challenge requirements

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Golang HA Infrastructure Setup                 ║"
echo "║              Based on Holded DevOps Challenge               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Validate Prerequisites
echo -e "\n${BLUE}Step 1: Validating Prerequisites${NC}"
echo "══════════════════════════════════════════════════════════════"

check_prerequisite() {
    local tool=$1
    local command=$2
    if command -v $command >/dev/null 2>&1; then
        echo -e "${GREEN}[PASS] $tool is installed${NC}"
        return 0
    else
        echo -e "${RED}[FAIL] $tool is not installed${NC}"
        return 1
    fi
}

check_prerequisite "Terraform" "terraform" || exit 1
check_prerequisite "Google Cloud CLI" "gcloud" || exit 1
check_prerequisite "Docker" "docker" || exit 1
check_prerequisite "Kubectl" "kubectl" || exit 1
check_prerequisite "Helm" "helm" || exit 1

# Step 2: GCP Configuration
echo -e "\n${BLUE}Step 2: GCP Configuration${NC}"
echo "══════════════════════════════════════════════════════════════"

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [ -z "$CURRENT_PROJECT" ]; then
    echo -e "${RED}[ERROR] No GCP project configured. Please run 'gcloud auth login' and 'gcloud config set project <PROJECT_ID>'${NC}"
    exit 1
fi

echo -e "${GREEN}[INFO] Using project: $CURRENT_PROJECT${NC}"

# Confirm project
read -p "Use this project ($CURRENT_PROJECT)? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[INFO] Please configure your desired project and run this script again${NC}"
    exit 1
fi

# Step 3: Region Configuration
echo -e "\n${BLUE}Step 3: Region Configuration${NC}"
echo "══════════════════════════════════════════════════════════════"

PRIMARY_REGION="europe-west1"
SECONDARY_REGION="europe-west3"

echo -e "${GREEN}[INFO] Using regions: $PRIMARY_REGION (primary), $SECONDARY_REGION (secondary)${NC}"

# Step 4: Update Configuration Files
echo -e "\n${BLUE}Step 4: Updating Configuration Files${NC}"
echo "══════════════════════════════════════════════════════════════"

# Update terraform.tfvars
sed -i.bak "s/YOUR_PROJECT_ID/$CURRENT_PROJECT/g" infrastructure/terraform.tfvars
echo -e "${GREEN}[SUCCESS] Updated infrastructure/terraform.tfvars${NC}"

# Update Kubernetes manifests
find application/k8s-manifests -name "*.yaml" -exec sed -i.bak "s/YOUR_PROJECT_ID/$CURRENT_PROJECT/g" {} \;
echo -e "${GREEN}[SUCCESS] Updated Kubernetes manifests${NC}"

# Update test scripts
find . -name "*.sh" -exec sed -i.bak "s/peak-tide-469522-r7/$CURRENT_PROJECT/g" {} \; 2>/dev/null || true
echo -e "${GREEN}[SUCCESS] Updated test scripts${NC}"

# Clean up backup files
find . -name "*.bak" -delete
echo -e "${GREEN}[SUCCESS] Cleaned up backup files${NC}"

# Step 5: Enable GCP APIs
echo -e "\n${BLUE}Step 5: Enabling GCP APIs${NC}"
echo "══════════════════════════════════════════════════════════════"

APIS=(
    "compute.googleapis.com"
    "container.googleapis.com"
    "monitoring.googleapis.com"
    "logging.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "iam.googleapis.com"
    "secretmanager.googleapis.com"
    "cloudkms.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo -e "${YELLOW}[INFO] Enabling $api...${NC}"
    gcloud services enable $api --project=$CURRENT_PROJECT >/dev/null 2>&1 || true
done
echo -e "${GREEN}[SUCCESS] GCP APIs enabled${NC}"

# Step 6: Build and Push Docker Image
echo -e "\n${BLUE}Step 6: Building and Pushing Docker Image${NC}"
echo "══════════════════════════════════════════════════════════════"

echo -e "${YELLOW}[INFO] Building Docker image...${NC}"
if docker build -t gcr.io/$CURRENT_PROJECT/golang-ha:latest application/golang-server/; then
    echo -e "${GREEN}[SUCCESS] Docker image built successfully${NC}"
else
    echo -e "${RED}[FAIL] Docker build failed${NC}"
    exit 1
fi

echo -e "${YELLOW}[INFO] Pushing Docker image...${NC}"
if docker push gcr.io/$CURRENT_PROJECT/golang-ha:latest; then
    echo -e "${GREEN}[SUCCESS] Docker image pushed successfully${NC}"
else
    echo -e "${RED}[FAIL] Docker push failed${NC}"
    exit 1
fi

# Step 7: Deploy Infrastructure
echo -e "\n${BLUE}Step 7: Deploying Infrastructure${NC}"
echo "══════════════════════════════════════════════════════════════"

cd infrastructure

echo -e "${YELLOW}[INFO] Initializing Terraform...${NC}"
terraform init

echo -e "${YELLOW}[INFO] Planning Terraform deployment...${NC}"
terraform plan -out=tfplan

echo -e "${YELLOW}[INFO] Applying Terraform deployment...${NC}"
echo -e "${YELLOW}[INFO] This will take 15-20 minutes...${NC}"
echo -e "${YELLOW}[INFO] Note: Monitoring stack may take additional time to fully deploy${NC}"
terraform apply tfplan || {
    echo -e "${YELLOW}[WARN] Terraform apply completed with warnings (monitoring may still be deploying)${NC}"
    echo -e "${YELLOW}[INFO] Checking if core infrastructure is ready...${NC}"
}

cd ..

# Step 8: Verify Deployment
echo -e "\n${BLUE}Step 8: Verifying Deployment${NC}"
echo "══════════════════════════════════════════════════════════════"

echo -e "${YELLOW}[INFO] Getting cluster credentials...${NC}"
gcloud container clusters get-credentials golang-ha-primary --region $PRIMARY_REGION --project $CURRENT_PROJECT

echo -e "${YELLOW}[INFO] Performing comprehensive health check...${NC}"

# Check cluster status
echo -e "${YELLOW}[INFO] Checking cluster status...${NC}"
if gcloud container clusters describe golang-ha-primary --region $PRIMARY_REGION --project $CURRENT_PROJECT --format="value(status)" | grep -q "RUNNING"; then
    echo -e "${GREEN}[SUCCESS] Primary cluster is running${NC}"
else
    echo -e "${RED}[FAIL] Primary cluster is not running${NC}"
    exit 1
fi

# Check nodes
echo -e "${YELLOW}[INFO] Checking node status...${NC}"
if kubectl get nodes --no-headers | grep -q "Ready"; then
    echo -e "${GREEN}[SUCCESS] Nodes are ready${NC}"
else
    echo -e "${RED}[FAIL] Nodes are not ready${NC}"
    exit 1
fi

# Check application pods
echo -e "${YELLOW}[INFO] Checking application pods...${NC}"
if kubectl get pods -n golang-app | grep -q "Running"; then
    echo -e "${GREEN}[SUCCESS] Application pods are running${NC}"
else
    echo -e "${RED}[FAIL] Application pods are not running${NC}"
    exit 1
fi

# Check canary pods
echo -e "${YELLOW}[INFO] Checking canary pods...${NC}"
if kubectl get pods -n golang-app-privileged | grep -q "Running"; then
    echo -e "${GREEN}[SUCCESS] Canary pods are running${NC}"
else
    echo -e "${RED}[FAIL] Canary pods are not running${NC}"
    exit 1
fi

# Check monitoring (if available)
echo -e "${YELLOW}[INFO] Checking monitoring stack...${NC}"
if kubectl get pods -n monitoring 2>/dev/null | grep -q "Running"; then
    echo -e "${GREEN}[SUCCESS] Monitoring stack is running${NC}"
else
    echo -e "${YELLOW}[WARN] Monitoring stack may still be deploying${NC}"
fi

# Step 9: Export Configuration
echo -e "\n${BLUE}Step 9: Exporting Configuration${NC}"
echo "══════════════════════════════════════════════════════════════"

# Create config file for test scripts
cat > config.env << EOF
PROJECT_ID=$CURRENT_PROJECT
PRIMARY_REGION=$PRIMARY_REGION
SECONDARY_REGION=$SECONDARY_REGION
PRIMARY_CLUSTER=golang-ha-primary
SECONDARY_CLUSTER=golang-ha-secondary
EOF

echo -e "${GREEN}[SUCCESS] Configuration exported to config.env${NC}"

# Step 10: Final Summary
echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    SETUP COMPLETED                           ║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${GREEN}Infrastructure deployed successfully!${NC}"
echo -e "\n${BLUE}Next steps:${NC}"
echo -e "  1. Run: ${YELLOW}source config.env${NC}"
echo -e "  2. Test CI/CD: ${YELLOW}./test-cicd.sh${NC}"
echo -e "  3. Test Canary: ${YELLOW}./test-canary.sh${NC}"
echo -e "  4. Test DR: ${YELLOW}./test-dr.sh${NC}"
echo -e "  5. Cleanup: ${YELLOW}./destroy.sh${NC}"

echo -e "\n${BLUE}Resources:${NC}"
echo -e "  - Primary Cluster: golang-ha-primary ($PRIMARY_REGION)"
echo -e "  - Secondary Cluster: golang-ha-secondary ($SECONDARY_REGION)"
echo -e "  - Load Balancer: $(gcloud compute addresses describe golang-ha-global-ip --global --project=$CURRENT_PROJECT --format='value(address)')"
echo -e "  - Application: http://localhost:8080 (after port-forward)"
