#!/bin/bash

# Golang HA Server Deployment Script
# This script automates the deployment of the Golang HA server on GCP

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists terraform; then
        missing_tools+=("terraform")
    fi
    
    if ! command_exists kubectl; then
        missing_tools+=("kubectl")
    fi
    
    if ! command_exists gcloud; then
        missing_tools+=("gcloud")
    fi
    
    if ! command_exists docker; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to setup GCP authentication
setup_gcp_auth() {
    print_status "Setting up GCP authentication..."
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_warning "No active GCP account found. Please authenticate:"
        gcloud auth login
    else
        print_success "GCP authentication is already configured"
    fi
    
    # Set project if provided
    if [ -n "$GCP_PROJECT_ID" ]; then
        gcloud config set project "$GCP_PROJECT_ID"
        print_success "GCP project set to: $GCP_PROJECT_ID"
    fi
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure..."
    
    cd infrastructure
    
    # Check if terraform.tfvars exists
    if [ ! -f terraform.tfvars ]; then
        print_warning "terraform.tfvars not found. Creating from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_error "Please edit terraform.tfvars with your configuration and run the script again."
        exit 1
    fi
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Ask for confirmation
    read -p "Do you want to apply this plan? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Applying Terraform plan..."
        terraform apply tfplan
        print_success "Infrastructure deployment completed"
    else
        print_warning "Deployment cancelled"
        exit 0
    fi
    
    cd ..
}

# Function to build and deploy application
deploy_application() {
    print_status "Building and deploying application..."
    
    cd application/golang-server
    
    # Build Go application
    print_status "Building Go application..."
    go mod tidy
    go build -o main .
    
    # Build Docker image
    print_status "Building Docker image..."
    docker build -t golang-ha-server:latest .
    
    # Get GCP project ID
    local project_id=$(gcloud config get-value project)
    
    # Tag and push image
    print_status "Pushing Docker image to GCR..."
    docker tag golang-ha-server:latest gcr.io/$project_id/golang-ha-server:latest
    docker push gcr.io/$project_id/golang-ha-server:latest
    
    print_success "Application image pushed to GCR"
    
    cd ../..
}

# Function to apply Kubernetes manifests
apply_k8s_manifests() {
    print_status "Applying Kubernetes manifests..."
    
    cd application/k8s-manifests
    
    # Get GCP project ID
    local project_id=$(gcloud config get-value project)
    
    # Replace PROJECT_ID placeholder in manifests
    sed -i.bak "s/PROJECT_ID/$project_id/g" deployment.yaml
    sed -i.bak "s/PROJECT_ID/$project_id/g" canary-deployment.yaml
    
    # Apply manifests
    kubectl apply -f deployment.yaml
    kubectl apply -f canary-deployment.yaml
    
    # Wait for deployment
    print_status "Waiting for deployment to be ready..."
    kubectl rollout status deployment/golang-app --timeout=300s
    
    print_success "Kubernetes manifests applied successfully"
    
    cd ../..
}

# Function to setup security
setup_security() {
    print_status "Setting up security components..."
    
    cd security
    
    # Apply security policies
    kubectl apply -f pod-security-policies.yaml
    kubectl apply -f audit-logging.yaml
    
    print_success "Security components deployed"
    
    cd ..
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check if pods are running
    local pod_status=$(kubectl get pods -l app=golang-app -o jsonpath='{.items[*].status.phase}')
    if [[ $pod_status == *"Running"* ]]; then
        print_success "Application pods are running"
    else
        print_error "Application pods are not running properly"
        kubectl get pods -l app=golang-app
        exit 1
    fi
    
    # Check if service is accessible
    local service_ip=$(kubectl get service golang-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -n "$service_ip" ]; then
        print_success "Service is accessible at: $service_ip"
    else
        print_warning "Service IP not available yet"
    fi
    
    # Get cluster info
    print_status "Cluster information:"
    kubectl cluster-info
}

# Function to display next steps
display_next_steps() {
    print_success "Deployment completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Configure your domain DNS to point to the load balancer IP"
    echo "2. Set up SSL certificates (Let's Encrypt)"
    echo "3. Configure monitoring dashboards"
    echo "4. Set up alerts and notifications"
    echo "5. Test the application endpoints"
    echo
    echo "Useful commands:"
    echo "  kubectl get pods -o wide"
    echo "  kubectl logs -f deployment/golang-app"
    echo "  kubectl get services"
    echo "  kubectl get ingress"
}

# Main deployment function
main() {
    echo "🚀 Golang HA Server Deployment Script"
    echo "====================================="
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Setup GCP authentication
    setup_gcp_auth
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Build and deploy application
    deploy_application
    
    # Apply Kubernetes manifests
    apply_k8s_manifests
    
    # Setup security
    setup_security
    
    # Verify deployment
    verify_deployment
    
    # Display next steps
    display_next_steps
}

# Check if script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    main "$@"
fi
