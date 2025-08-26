#!/bin/bash

# DevOps Challenge - Simple Cleanup Script
# This is a demonstration script - may require additional steps for complete cleanup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}=== DevOps Challenge Cleanup ===${NC}"
echo -e "${YELLOW}Note: This is a demonstration cleanup script${NC}"
echo -e "${YELLOW}For complete cleanup, manual verification may be required${NC}"
echo ""

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ -z "$CURRENT_PROJECT" ]; then
    echo -e "${RED}[ERROR] No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID${NC}"
    exit 1
fi

echo -e "${YELLOW}[INFO] Cleaning up project: $CURRENT_PROJECT${NC}"

# Step 1: Terraform Destroy
echo -e "\n${YELLOW}[STEP 1] Destroying Terraform Infrastructure...${NC}"

cd 1_infrastructure

if [ -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}[INFO] Running terraform destroy...${NC}"
    terraform destroy -var="project_id=$CURRENT_PROJECT" -auto-approve
    echo -e "${GREEN}[SUCCESS] Terraform resources destroyed${NC}"
else
    echo -e "${YELLOW}[INFO] No terraform.tfstate found, skipping terraform destroy${NC}"
fi

cd ..

# Step 2: Clean Docker Images
echo -e "\n${YELLOW}[STEP 2] Cleaning Docker Images...${NC}"

# Remove local Docker images
echo -e "${YELLOW}[INFO] Removing local Docker images...${NC}"
docker rmi gcr.io/$CURRENT_PROJECT/golang-ha:latest 2>/dev/null || echo -e "${YELLOW}[INFO] Local image not found${NC}"

# List GCR images (for manual cleanup)
echo -e "${YELLOW}[INFO] Listing remaining GCR images:${NC}"
gcloud container images list --repository=gcr.io/$CURRENT_PROJECT 2>/dev/null || echo -e "${YELLOW}[INFO] No GCR images found${NC}"

# Step 3: Clean Kubernetes Resources
echo -e "\n${YELLOW}[STEP 3] Cleaning Kubernetes Resources...${NC}"

# Check for remaining clusters
echo -e "${YELLOW}[INFO] Checking for remaining GKE clusters:${NC}"
gcloud container clusters list --format="table(name,location,status)" 2>/dev/null || echo -e "${YELLOW}[INFO] No clusters found${NC}"

# Step 4: Manual Cleanup Reminder
echo -e "\n${YELLOW}[STEP 4] Manual Verification Recommended...${NC}"

echo -e "${YELLOW}[INFO] Please manually verify cleanup of:${NC}"
echo -e "- Load balancers: gcloud compute forwarding-rules list"
echo -e "- Persistent disks: gcloud compute disks list"
echo -e "- Static IPs: gcloud compute addresses list"
echo -e "- VPC networks: gcloud compute networks list"
echo -e "- Firewall rules: gcloud compute firewall-rules list"
echo -e "- Container images: gcloud container images list"

# Final Status
echo -e "\n${GREEN}=== Cleanup Complete ===${NC}"
echo ""
echo -e "${YELLOW}Note: This demo script handles basic cleanup.${NC}"
echo -e "${YELLOW}For complete cleanup, verify all resources manually.${NC}"
echo -e "${YELLOW}Some resources may persist and continue to incur charges.${NC}"