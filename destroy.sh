#!/bin/bash

# Golang HA Server - Destroy Script
# This script destroys all resources created by the deployment

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

# Function to confirm destruction
confirm_destruction() {
    echo
    print_warning "This will destroy ALL resources created by the deployment:"
    echo "  - GKE clusters (primary and secondary)"
    echo "  - VPC network and subnets"
    echo "  - Load balancer and SSL certificates"
    echo "  - Monitoring stack (Prometheus, Grafana)"
    echo "  - ArgoCD"
    echo "  - Application deployments"
    echo "  - Audit logging configuration"
    echo "  - All associated GCP resources"
    echo
    print_warning "This action is IRREVERSIBLE!"
    echo
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        print_status "Destruction cancelled"
        exit 0
    fi
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_status "Destroying infrastructure with Terraform..."
    
    # Change to infrastructure directory
    cd infrastructure
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        terraform init
    fi
    
    # Plan the destruction
    print_status "Planning Terraform destruction..."
    terraform plan -destroy -out=destroy-plan
    
    # Apply the destruction
    print_status "Applying Terraform destruction..."
    terraform apply destroy-plan
    
    # Return to root directory
    cd ..
    
    print_success "Infrastructure destruction completed successfully"
}

# Function to cleanup local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    # Remove Terraform files from infrastructure directory
    rm -f infrastructure/tfplan infrastructure/destroy-plan
    rm -f infrastructure/terraform.tfvars.bak
    
    # Remove Terraform files from root directory
    rm -f tfplan destroy-plan
    rm -f terraform.tfvars.bak
    
    print_success "Local cleanup completed"
}

# Main execution
main() {
    print_status "Starting Golang HA Server destruction..."
    echo
    
    # Confirm destruction
    confirm_destruction
    
    # Destroy infrastructure
    destroy_infrastructure
    
    # Cleanup local files
    cleanup_local_files
    
    print_success "All resources have been destroyed successfully!"
    echo
    print_warning "Note: Some resources like BigQuery datasets may take time to be fully cleaned up by GCP"
}

# Run main function
main "$@"
