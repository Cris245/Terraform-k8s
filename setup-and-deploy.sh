#!/bin/bash

# Setup and Deploy Script
# Comprehensive setup and deployment for Golang HA Infrastructure
# This script handles configuration, validation, and deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

print_header() {
    echo -e "${PURPLE}$1${NC}"
}

echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Golang HA Infrastructure Setup                 ║"
echo "║                Configuration and Deployment                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Validate prerequisites
print_header "Step 1: Validating Prerequisites"
echo "══════════════════════════════════════════════════════════════"

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    echo "Install Terraform: https://www.terraform.io/downloads"
    exit 1
fi

if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed"
    echo "Install gcloud: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    echo "Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    echo "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

print_status "All prerequisites are installed"

# Step 2: GCP Authentication and Project Configuration
print_header "Step 2: GCP Authentication and Project Configuration"
echo "══════════════════════════════════════════════════════════════"

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    print_warning "Not authenticated with gcloud"
    print_info "Please run: gcloud auth login"
    gcloud auth login
fi

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")

if [ -z "$CURRENT_PROJECT" ]; then
    print_error "No GCP project configured"
    echo "Please run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo "Current GCP project: $CURRENT_PROJECT"

# Confirm project
read -p "Use this project ID ($CURRENT_PROJECT)? (y/n): " confirm
if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    read -p "Enter your GCP project ID: " PROJECT_ID
else
    PROJECT_ID=$CURRENT_PROJECT
fi

print_status "Using project: $PROJECT_ID"

# Step 3: Region Configuration
print_header "Step 3: Region Configuration"
echo "══════════════════════════════════════════════════════════════"

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
    
    print_status "Using regions: $PRIMARY_REGION (primary), $SECONDARY_REGION (secondary)"
else
    PRIMARY_REGION="europe-west1"
    SECONDARY_REGION="europe-west3"
    print_status "Using default regions: $PRIMARY_REGION (primary), $SECONDARY_REGION (secondary)"
fi

# Step 4: Update Configuration Files
print_header "Step 4: Updating Configuration Files"
echo "══════════════════════════════════════════════════════════════"

# Update Terraform configuration
if [ -f "infrastructure/terraform.tfvars" ]; then
    sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" infrastructure/terraform.tfvars
    sed -i.bak "s/europe-west1/$PRIMARY_REGION/g" infrastructure/terraform.tfvars
    sed -i.bak "s/europe-west3/$SECONDARY_REGION/g" infrastructure/terraform.tfvars
    print_status "Updated infrastructure/terraform.tfvars"
else
    print_error "infrastructure/terraform.tfvars not found"
    exit 1
fi

# Update Kubernetes manifests
if [ -d "application/k8s-manifests" ]; then
    find application/k8s-manifests/ -name "*.yaml" -exec sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" {} \;
    print_status "Updated Kubernetes manifests"
fi

# Update test scripts
find . -name "*.sh" -exec sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" {} \;
print_status "Updated test scripts"

# Clean up backup files
find . -name "*.bak" -delete
print_status "Cleaned up backup files"

# Step 5: Enable Required APIs
print_header "Step 5: Enabling Required GCP APIs"
echo "══════════════════════════════════════════════════════════════"

print_info "Enabling required GCP APIs..."
gcloud services enable container.googleapis.com --project=$PROJECT_ID
gcloud services enable compute.googleapis.com --project=$PROJECT_ID
gcloud services enable monitoring.googleapis.com --project=$PROJECT_ID
gcloud services enable logging.googleapis.com --project=$PROJECT_ID
gcloud services enable bigquery.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudresourcemanager.googleapis.com --project=$PROJECT_ID
print_status "GCP APIs enabled"

# Step 6: Build and Push Docker Image
print_header "Step 6: Building and Pushing Application"
echo "══════════════════════════════════════════════════════════════"

print_info "Building Docker image..."
cd application/golang-server
docker buildx build --platform linux/amd64 -t gcr.io/${PROJECT_ID}/golang-ha-app:latest .
docker push gcr.io/${PROJECT_ID}/golang-ha-app:latest
cd ../../infrastructure

print_status "Docker image pushed to gcr.io/${PROJECT_ID}/golang-ha-app:latest"

# Step 7: Deploy Infrastructure with Terraform
print_header "Step 7: Deploying Infrastructure with Terraform"
echo "══════════════════════════════════════════════════════════════"

print_info "Terraform will deploy:"
print_info "  - GKE clusters (primary + secondary)"
print_info "  - Istio service mesh"
print_info "  - Application deployment"
print_info "  - Monitoring stack (Prometheus/Grafana)"
print_info "  - ArgoCD for GitOps"
print_info "  - Load balancer and networking"
print_info "  - Security configurations"
print_info "  - Audit logging"

echo ""
print_warning "This will take 15-20 minutes to complete"
print_warning "Make sure you have sufficient GCP quota"
echo ""

read -p "Press Enter to continue with terraform apply..."

# Initialize Terraform
print_info "Initializing Terraform..."
terraform init

# Plan Terraform
print_info "Planning Terraform deployment..."
terraform plan -out=tfplan

# Apply Terraform
print_info "Applying Terraform configuration..."
terraform apply tfplan

# Step 8: Post-Deployment Configuration
print_header "Step 8: Post-Deployment Configuration"
echo "══════════════════════════════════════════════════════════════"

print_info "Configuring kubectl for primary cluster..."
gcloud container clusters get-credentials golang-ha-primary --region=$PRIMARY_REGION --project=$PROJECT_ID

print_info "Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod --all --all-namespaces --timeout=600s

print_status "Infrastructure deployment completed successfully!"

# Step 9: Display Results
print_header "Step 9: Deployment Results"
echo "══════════════════════════════════════════════════════════════"

print_info "Getting deployment information..."
echo ""

# Get load balancer IP
LB_IP=$(terraform output -raw load_balancer_ip 2>/dev/null || echo "Not available")
if [ "$LB_IP" != "Not available" ]; then
    print_status "Load Balancer IP: $LB_IP"
    print_info "Application URL: https://$LB_IP"
    print_info "Health Check: https://$LB_IP/health"
    print_info "Metrics: https://$LB_IP/metrics"
else
    print_warning "Load balancer IP not available yet"
fi

echo ""
print_status "Deployment Summary:"
print_info "  - Primary Cluster: golang-ha-primary ($PRIMARY_REGION)"
print_info "  - Secondary Cluster: golang-ha-secondary ($SECONDARY_REGION)"
print_info "  - Application: Deployed and running"
print_info "  - Monitoring: Prometheus/Grafana available"
print_info "  - GitOps: ArgoCD configured"

echo ""
print_header "Next Steps:"
echo "══════════════════════════════════════════════════════════════"
print_info "1. Test the application: ./run-all-tests.sh"
print_info "2. Access Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
print_info "3. Access ArgoCD: kubectl port-forward -n argocd svc/argocd-server 8080:443"
print_info "4. View logs: kubectl logs -n golang-app -l app=golang-app"
print_info "5. Monitor resources: kubectl top pods -n golang-app"

echo ""
print_info "Documentation:"
print_info "  - README.md - Quick start guide"
print_info "  - TECHNICAL_DECISIONS.md - Architecture rationale"
print_info "  - ARCHITECTURE_DIAGRAM.md - System diagrams"
print_info "  - DISASTER_RECOVERY_PLAN.md - DR procedures"

echo ""
print_status "Setup and deployment complete! Your Golang HA infrastructure is ready."
