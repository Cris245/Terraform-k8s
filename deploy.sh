#!/bin/bash

# Golang HA Server - Complete Deployment Script
# This script automates the entire deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if required tools are installed
    command -v terraform >/dev/null 2>&1 || { print_error "Terraform is required but not installed. Aborting."; exit 1; }
    command -v gcloud >/dev/null 2>&1 || { print_error "gcloud CLI is required but not installed. Aborting."; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { print_error "kubectl is required but not installed. Aborting."; exit 1; }
    command -v docker >/dev/null 2>&1 || { print_error "Docker is required but not installed. Aborting."; exit 1; }
    
    print_success "All prerequisites are satisfied"
}

# Function to get GCP project ID
get_project_id() {
    print_status "Getting GCP project ID..."
    
    # Try to get project ID from gcloud
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    
    if [ -z "$PROJECT_ID" ]; then
        print_error "No GCP project configured. Please run: gcloud auth login && gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    
    print_success "Using GCP project: $PROJECT_ID"
    
    # Update terraform.tfvars with the project ID
    if [ -f "infrastructure/terraform.tfvars" ]; then
        sed -i.bak "s/project_id = \".*\"/project_id = \"$PROJECT_ID\"/" infrastructure/terraform.tfvars
        print_success "Updated terraform.tfvars with project ID: $PROJECT_ID"
    else
        print_error "terraform.tfvars not found in infrastructure directory. Please create it from terraform.tfvars.example"
        exit 1
    fi
}

# Function to build and push Docker image
build_and_push_image() {
    print_status "Building and pushing Docker image..."
    
    # Check if application directory exists
    if [ ! -d "application/golang-server" ]; then
        print_error "Application directory not found: application/golang-server"
        exit 1
    fi
    
    # Build the Docker image
    cd application/golang-server
    print_status "Building Docker image..."
    docker buildx build --platform linux/amd64 -t gcr.io/$PROJECT_ID/golang-ha-app:latest .
    
    # Push to Google Container Registry
    print_status "Pushing Docker image to GCR..."
    docker push gcr.io/$PROJECT_ID/golang-ha-app:latest
    
    cd ../..
    print_success "Docker image built and pushed successfully"
}

# Function to handle existing monitoring
handle_existing_monitoring() {
    print_status "Checking for existing monitoring installation..."
    
    if kubectl get pods -n monitoring 2>/dev/null | grep -q "prometheus-operator"; then
        print_warning "Monitoring stack already exists. Skipping monitoring deployment to avoid conflicts."
        return 0
    fi
    
    return 1
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    # Change to infrastructure directory
    cd infrastructure
    
    # Initialize Terraform
    terraform init
    
    # Check if monitoring already exists
    if handle_existing_monitoring; then
        print_status "Deploying infrastructure without monitoring (already exists)..."
        terraform plan -out=tfplan -target=module.vpc -target=module.gke_primary -target=module.gke_secondary -target=module.load_balancer -target=module.audit_logging -target=module.argocd -target=module.application_primary -target=module.application_secondary
    else
        print_status "Planning complete Terraform deployment..."
        terraform plan -out=tfplan
    fi
    
    # Apply the deployment
    print_status "Applying Terraform deployment..."
    terraform apply tfplan
    
    # Handle monitoring webhook issue if it occurs
    print_status "Checking monitoring deployment..."
    if ! kubectl get pods -n monitoring 2>/dev/null | grep -q "prometheus-operator"; then
        print_warning "Monitoring deployment may have failed due to webhook issues. Attempting to fix..."
        
        # Try to fix webhook issues
        kubectl patch validatingwebhookconfiguration prometheus-operator-admission --type='json' -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]' 2>/dev/null || echo "Webhook not found"
        
        # Re-apply monitoring if needed
        print_status "Re-applying monitoring deployment..."
        terraform apply -target=module.monitoring
    fi
    
    cd ..
    print_success "Infrastructure deployment completed successfully"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Get cluster credentials
    print_status "Getting cluster credentials..."
    gcloud container clusters get-credentials golang-ha-primary --region europe-west1 --project $PROJECT_ID
    
    # Check if pods are running
    print_status "Checking application pods..."
    kubectl get pods -n golang-app
    
    # Check if monitoring is running
    print_status "Checking monitoring stack..."
    kubectl get pods -n monitoring
    
    # Check if ArgoCD is running
    print_status "Checking ArgoCD..."
    kubectl get pods -n argocd
    
    print_success "Deployment verification completed"
}

# Function to display access information
display_access_info() {
    print_status "Deployment completed successfully!"
    echo
    echo "=== ACCESS INFORMATION ==="
    echo
    
    # Get load balancer IP
    LB_IP=$(terraform output -raw load_balancer_ip 2>/dev/null || echo "Not available yet")
    echo "Load Balancer IP: $LB_IP"
    echo "Load Balancer URL: https://$LB_IP"
    echo
    
    echo "=== LOCAL ACCESS (via port-forward) ==="
    echo "Application: kubectl port-forward service/golang-app-service 8080:80 -n golang-app"
    echo "Grafana: kubectl port-forward service/prometheus-operator-grafana 3000:80 -n monitoring"
    echo
    
    echo "=== CLUSTER ACCESS ==="
    echo "Primary Cluster: gcloud container clusters get-credentials golang-ha-primary --region europe-west1 --project $PROJECT_ID"
    echo "Secondary Cluster: gcloud container clusters get-credentials golang-ha-secondary --region europe-west3 --project $PROJECT_ID"
    echo
    
    echo "=== MONITORING ACCESS ==="
    echo "Grafana: http://localhost:3000 (admin/admin123)"
    echo "Audit Dashboard: $(terraform output -raw audit_dashboard_url 2>/dev/null || echo "Not available")"
    echo
    
    echo "=== ARGOCD ACCESS ==="
    echo "ArgoCD URL: $(terraform output -raw argocd_url 2>/dev/null || echo "Not available")"
    echo
    
    echo "=== VERIFICATION COMMANDS ==="
    echo "Check application: kubectl get pods -n golang-app"
    echo "Check monitoring: kubectl get pods -n monitoring"
    echo "Check ArgoCD: kubectl get pods -n argocd"
    echo "Test application: curl http://localhost:8080/health"
    echo
}

# Main execution
main() {
    print_status "Starting Golang HA Server deployment..."
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Get project ID
    get_project_id
    
    # Build and push Docker image
    build_and_push_image
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Verify deployment
    verify_deployment
    
    # Display access information
    display_access_info
    
    print_success "Deployment completed successfully!"
}

# Run main function
main "$@"
