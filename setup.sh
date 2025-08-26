#!/bin/bash

# DevOps Challenge - Simple Setup Script
# This is a demonstration script - may require additional configuration for full production use

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== DevOps Challenge Setup ===${NC}"
echo -e "${YELLOW}Note: This is a demonstration script for the challenge${NC}"
echo -e "${YELLOW}For production use, additional configuration may be required${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[INFO] Checking prerequisites...${NC}"

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}[ERROR] gcloud CLI not found. Please install Google Cloud SDK${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}[ERROR] terraform not found. Please install Terraform >= 1.0${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR] docker not found. Please install Docker${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}[ERROR] kubectl not found. Please install kubectl${NC}"
    exit 1
fi

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ -z "$CURRENT_PROJECT" ]; then
    echo -e "${RED}[ERROR] No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID${NC}"
    exit 1
fi

echo -e "${GREEN}[SUCCESS] Using GCP project: $CURRENT_PROJECT${NC}"

# Step 1: Infrastructure Setup
echo -e "\n${YELLOW}[STEP 1] Setting up Infrastructure...${NC}"

cd 1_infrastructure

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}[INFO] Creating terraform.tfvars from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    sed -i.bak "s/your-gcp-project-id/$CURRENT_PROJECT/g" terraform.tfvars
    echo -e "${GREEN}[SUCCESS] Created and configured terraform.tfvars${NC}"
fi

# Initialize Terraform
echo -e "${YELLOW}[INFO] Initializing Terraform...${NC}"
terraform init

# Plan deployment
echo -e "${YELLOW}[INFO] Planning Terraform deployment...${NC}"
terraform plan -var="project_id=$CURRENT_PROJECT"

echo -e "\n${YELLOW}[READY] Infrastructure planned successfully${NC}"
echo -e "${YELLOW}To deploy: terraform apply -var=\"project_id=$CURRENT_PROJECT\"${NC}"

cd ..

# Step 2: Application Setup
echo -e "\n${YELLOW}[STEP 2] Setting up Application...${NC}"

# Configure Docker for GCR
echo -e "${YELLOW}[INFO] Configuring Docker for Google Container Registry...${NC}"
gcloud auth configure-docker --quiet

# Update Kubernetes manifests
echo -e "${YELLOW}[INFO] Updating Kubernetes manifests...${NC}"
find 2_application/k8s-manifests -name "*.yaml" -exec sed -i.bak "s/YOUR_PROJECT_ID/$CURRENT_PROJECT/g" {} \;

echo -e "${GREEN}[SUCCESS] Application configured for project: $CURRENT_PROJECT${NC}"

# Step 3: Build Application
echo -e "\n${YELLOW}[STEP 3] Building Application...${NC}"

echo -e "${YELLOW}[INFO] Building Docker image...${NC}"
docker build -t gcr.io/$CURRENT_PROJECT/golang-ha:latest 2_application/golang-server/

echo -e "${GREEN}[SUCCESS] Docker image built: gcr.io/$CURRENT_PROJECT/golang-ha:latest${NC}"
echo -e "${YELLOW}To push: docker push gcr.io/$CURRENT_PROJECT/golang-ha:latest${NC}"

# Final Instructions
echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo ""
echo -e "${YELLOW}Next steps for full deployment:${NC}"
echo -e "1. Deploy infrastructure: cd 1_infrastructure && terraform apply"
echo -e "2. Push Docker image: docker push gcr.io/$CURRENT_PROJECT/golang-ha:latest"
echo -e "3. Apply Kubernetes manifests: kubectl apply -f 2_application/k8s-manifests/"
echo -e "4. Apply security policies: kubectl apply -f 3_security/"
echo ""
echo -e "${YELLOW}Note: This demo script sets up the foundation.${NC}"
echo -e "${YELLOW}Production deployment may require additional configuration.${NC}"