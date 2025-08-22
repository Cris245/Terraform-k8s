#!/bin/bash

# Cluster Validation Script
# This script validates that GKE clusters are ready before deploying applications

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

# Get project ID from terraform
PROJECT_ID=$(terraform output -raw project_id 2>/dev/null || echo "peak-tide-469522-r7")
PRIMARY_REGION="europe-west1"
SECONDARY_REGION="europe-west3"
PRIMARY_CLUSTER="golang-ha-primary"
SECONDARY_CLUSTER="golang-ha-secondary"

print_status "Validating GKE clusters..."
print_status "Project ID: $PROJECT_ID"

# Function to validate a single cluster
validate_cluster() {
    local cluster_name=$1
    local region=$2
    local cluster_type=$3
    
    print_status "Validating $cluster_type cluster: $cluster_name in $region"
    
    # Check if cluster exists
    if ! gcloud container clusters describe "$cluster_name" --region="$region" --project="$PROJECT_ID" >/dev/null 2>&1; then
        print_error "Cluster $cluster_name does not exist in $region"
        return 1
    fi
    
    # Check cluster status
    local status=$(gcloud container clusters describe "$cluster_name" --region="$region" --project="$PROJECT_ID" --format="value(status)")
    if [ "$status" != "RUNNING" ]; then
        print_error "Cluster $cluster_name is not running. Status: $status"
        return 1
    fi
    
    # Get cluster credentials
    print_status "Getting credentials for $cluster_name..."
    gcloud container clusters get-credentials "$cluster_name" --region="$region" --project="$PROJECT_ID"
    
    # Check if kubectl can connect
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to cluster $cluster_name"
        return 1
    fi
    
    # Check node status
    print_status "Checking node status for $cluster_name..."
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready")
    local total_nodes=$(kubectl get nodes --no-headers | wc -l)
    
    if [ "$ready_nodes" -eq 0 ]; then
        print_error "No nodes are ready in cluster $cluster_name"
        return 1
    fi
    
    if [ "$ready_nodes" -lt "$total_nodes" ]; then
        print_warning "Some nodes are not ready in cluster $cluster_name ($ready_nodes/$total_nodes)"
    else
        print_success "All nodes are ready in cluster $cluster_name ($ready_nodes/$total_nodes)"
    fi
    
    # Check if namespaces exist
    print_status "Checking existing namespaces in $cluster_name..."
    if kubectl get namespace golang-app >/dev/null 2>&1; then
        print_warning "Namespace 'golang-app' already exists in $cluster_name"
    else
        print_status "Namespace 'golang-app' does not exist in $cluster_name"
    fi
    
    if kubectl get namespace golang-app-privileged >/dev/null 2>&1; then
        print_warning "Namespace 'golang-app-privileged' already exists in $cluster_name"
    else
        print_status "Namespace 'golang-app-privileged' does not exist in $cluster_name"
    fi
    
    print_success "$cluster_type cluster $cluster_name is ready"
    return 0
}

# Validate primary cluster
if validate_cluster "$PRIMARY_CLUSTER" "$PRIMARY_REGION" "Primary"; then
    PRIMARY_READY=true
else
    PRIMARY_READY=false
fi

# Validate secondary cluster
if validate_cluster "$SECONDARY_CLUSTER" "$SECONDARY_REGION" "Secondary"; then
    SECONDARY_READY=true
else
    SECONDARY_READY=false
fi

# Summary
echo
print_status "Validation Summary:"
if [ "$PRIMARY_READY" = true ]; then
    print_success "Primary cluster ($PRIMARY_CLUSTER) is ready"
else
    print_error "Primary cluster ($PRIMARY_CLUSTER) is not ready"
fi

if [ "$SECONDARY_READY" = true ]; then
    print_success "Secondary cluster ($SECONDARY_CLUSTER) is ready"
else
    print_error "Secondary cluster ($SECONDARY_CLUSTER) is not ready"
fi

if [ "$PRIMARY_READY" = true ] && [ "$SECONDARY_READY" = true ]; then
    print_success "All clusters are ready for application deployment"
    exit 0
else
    print_error "Some clusters are not ready. Please wait and try again."
    exit 1
fi
