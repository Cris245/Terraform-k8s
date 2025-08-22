#!/bin/bash

# Setup and Deploy Script
# This script only handles setup/preparation, Terraform does everything else

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW} $1${NC}"
}

print_error() {
    echo -e "${RED} $1${NC}"
}

echo -e "${BLUE} Setting up Golang HA Infrastructure (Pure Terraform)${NC}"

# Step 1: Validate prerequisites
echo -e "${BLUE} Step 1: Validating Prerequisites${NC}"
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
fi

if ! command -v gcloud &> /dev/null; then
    print_error "gcloud is not installed"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi

print_status "All prerequisites are installed"

# Step 2: Get project ID and update configuration
echo -e "${BLUE} Step 2: Updating Configuration${NC}"
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    print_error "No GCP project configured. Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_status "Using project: $PROJECT_ID"

# Update terraform.tfvars if needed
if [ -f "terraform.tfvars" ]; then
    if grep -q "YOUR_PROJECT_ID" terraform.tfvars; then
        sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" terraform.tfvars
        print_status "Updated terraform.tfvars with project ID"
    fi
else
    print_error "terraform.tfvars not found"
    exit 1
fi

# Step 3: Build and push Docker image
echo -e "${BLUE} Step 3: Building and Pushing Application${NC}"
print_status "Building Docker image..."
cd ../application/golang-server
docker buildx build --platform linux/amd64 -t gcr.io/${PROJECT_ID}/golang-ha-app:latest .
docker push gcr.io/${PROJECT_ID}/golang-ha-app:latest
cd ../../infrastructure

print_status "Docker image pushed to gcr.io/${PROJECT_ID}/golang-ha-app:latest"

# Step 4: Run Terraform
echo -e "${BLUE} Step 4: Running Terraform${NC}"
print_status "Terraform will handle everything else:"
print_status "  - GKE clusters (primary + secondary)"
print_status "  - Istio installation"
print_status "  - Application deployment"
print_status "  - Monitoring and ArgoCD"
print_status "  - Cross-cluster configuration"

echo ""
echo -e "${YELLOW}  This will take 15-20 minutes to complete${NC}"
echo -e "${YELLOW}  Make sure you have sufficient GCP quota${NC}"
echo ""

read -p "Press Enter to continue with terraform apply..."

# Run Terraform
terraform apply -auto-approve

echo ""
print_status "Setup complete! Terraform has deployed everything."
echo ""
echo -e "${BLUE} Next steps:${NC}"
echo -e "  1. Check the Terraform outputs for access information"
echo -e "  2. Run: terraform output to see all endpoints"
echo -e "  3. Test the application endpoints"
echo ""
