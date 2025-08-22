#!/bin/bash

# Setup script for Golang HA Server on GCP
# This script helps configure the project with your specific GCP project ID

set -e

echo "Golang HA Server Setup"
echo "======================"

# Check if gcloud is configured
if ! command -v gcloud &> /dev/null; then
    echo "ERROR: gcloud CLI not found. Please install it first:"
    echo "   https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")

if [ -z "$CURRENT_PROJECT" ]; then
    echo "ERROR: No GCP project configured. Please run:"
    echo "   gcloud auth login"
    echo "   gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo "Current GCP project: $CURRENT_PROJECT"
echo ""

# Confirm project
read -p "Use this project ID ($CURRENT_PROJECT)? (y/n): " confirm
if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    read -p "Enter your GCP project ID: " PROJECT_ID
else
    PROJECT_ID=$CURRENT_PROJECT
fi

echo ""
echo "Configuring project files with: $PROJECT_ID"

# Ask about regions
echo ""
echo "Current regions are set to: europe-west1 (primary), europe-west3 (secondary)"
read -p "Do you want to change the regions? (y/n): " change_regions

if [[ $change_regions == [yY] || $change_regions == [yY][eE][sS] ]]; then
    echo ""
    echo "Available regions examples:"
    echo "  Europe: europe-west1 (Belgium), europe-west3 (Frankfurt), europe-west4 (Netherlands)"
    echo "  US: us-central1 (Iowa), us-west1 (Oregon), us-east1 (S. Carolina)"
    echo "  Asia: asia-east1 (Taiwan), asia-southeast1 (Singapore)"
    echo ""
    read -p "Enter primary region [europe-west1]: " PRIMARY_REGION
    read -p "Enter secondary region [europe-west3]: " SECONDARY_REGION
    
    PRIMARY_REGION=${PRIMARY_REGION:-europe-west1}
    SECONDARY_REGION=${SECONDARY_REGION:-europe-west3}
    
    echo "Will use regions: $PRIMARY_REGION (primary), $SECONDARY_REGION (secondary)"
else
    PRIMARY_REGION="europe-west1"
    SECONDARY_REGION="europe-west3"
fi

# Update Terraform configuration
if [ -f "infrastructure/terraform.tfvars" ]; then
    sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" infrastructure/terraform.tfvars
    sed -i.bak "s/europe-west1/$PRIMARY_REGION/g" infrastructure/terraform.tfvars
    sed -i.bak "s/europe-west3/$SECONDARY_REGION/g" infrastructure/terraform.tfvars
    echo "Updated infrastructure/terraform.tfvars"
fi

# Update Kubernetes manifests
find application/k8s-manifests/ -name "*.yaml" -exec sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" {} \;
echo "Updated Kubernetes manifests"

# Update test scripts
find . -name "*.sh" -exec sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" {} \;
echo "Updated test scripts"

# Clean up backup files
find . -name "*.bak" -delete

echo ""
echo "Next Steps:"
echo "1. Review and customize infrastructure/terraform.tfvars"
echo "2. Run: ./deploy.sh"
echo "3. Follow the README.md for complete deployment instructions"
echo ""
echo "Documentation:"
echo "- README.md - Quick start guide"
echo "- TECHNICAL_DECISIONS.md - Architecture rationale"
echo "- ARCHITECTURE_DIAGRAM.md - System diagrams"
echo ""
echo "Setup complete! Your project is ready for deployment."
