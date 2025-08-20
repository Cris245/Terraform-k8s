#!/bin/bash

# ArgoCD GitOps Setup Script
# This script sets up ArgoCD applications for the Golang HA Server

set -euo pipefail

# Configuration
PROJECT_ID="${PROJECT_ID:-YOUR_PROJECT_ID}"
PRIMARY_REGION="${PRIMARY_REGION:-europe-west1}"
SECONDARY_REGION="${SECONDARY_REGION:-europe-west3}"
CLUSTER_NAME_PRIMARY="golang-ha-primary"
CLUSTER_NAME_SECONDARY="golang-ha-secondary"
ARGOCD_NAMESPACE="argocd"
DOMAIN_NAME="${DOMAIN_NAME:-golang-ha.example.com}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/Cris245/Terraform-k8s.git}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v argocd &> /dev/null; then
        log_warning "ArgoCD CLI not found. Installing..."
        install_argocd_cli
    fi
    
    if ! command -v gcloud &> /dev/null; then
        missing_tools+=("gcloud")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install them and run this script again."
        exit 1
    fi
    
    log_success "All prerequisites met!"
}

# Install ArgoCD CLI
install_argocd_cli() {
    local VERSION="v2.8.4"
    local OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    local ARCH="amd64"
    
    if [[ "$OS" == "darwin" ]]; then
        ARCH="arm64"
    fi
    
    log_info "Installing ArgoCD CLI ${VERSION}..."
    curl -sSL -o /tmp/argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-${OS}-${ARCH}"
    chmod +x /tmp/argocd
    sudo mv /tmp/argocd /usr/local/bin/argocd
    log_success "ArgoCD CLI installed successfully!"
}

# Connect to primary cluster
connect_to_cluster() {
    log_info "Connecting to primary GKE cluster..."
    
    gcloud container clusters get-credentials "${CLUSTER_NAME_PRIMARY}" \
        --region "${PRIMARY_REGION}" \
        --project "${PROJECT_ID}"
    
    log_success "Connected to ${CLUSTER_NAME_PRIMARY}"
}

# Wait for ArgoCD to be ready
wait_for_argocd() {
    log_info "Waiting for ArgoCD to be ready..."
    
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n ${ARGOCD_NAMESPACE}
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-application-controller -n ${ARGOCD_NAMESPACE}
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-repo-server -n ${ARGOCD_NAMESPACE}
    
    log_success "ArgoCD is ready!"
}

# Get ArgoCD admin password
get_argocd_password() {
    log_info "Retrieving ArgoCD admin password..."
    
    # Wait for the secret to be created
    kubectl wait --for=condition=available --timeout=300s secret/argocd-initial-admin-secret -n ${ARGOCD_NAMESPACE} || true
    
    local password
    password=$(kubectl get secret argocd-initial-admin-secret -n ${ARGOCD_NAMESPACE} -o jsonpath="{.data.password}" | base64 --decode)
    
    if [ -z "$password" ]; then
        log_warning "Could not retrieve auto-generated password. Using configured password."
        password="admin123"
    fi
    
    echo "$password"
}

# Setup port forwarding for ArgoCD
setup_port_forward() {
    log_info "Setting up port forwarding to ArgoCD..."
    
    # Kill existing port-forward if any
    pkill -f "kubectl.*port-forward.*argocd-server" || true
    sleep 2
    
    # Start port-forward in background
    kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8080:443 > /dev/null 2>&1 &
    local pf_pid=$!
    
    # Wait for port-forward to be ready
    log_info "Waiting for port-forward to be ready..."
    for i in {1..30}; do
        if curl -k -s https://localhost:8080 > /dev/null 2>&1; then
            log_success "Port-forward is ready!"
            break
        fi
        sleep 2
    done
    
    echo "$pf_pid"
}

# Login to ArgoCD
login_to_argocd() {
    local password="$1"
    local server="localhost:8080"
    
    log_info "Logging into ArgoCD..."
    
    # Login to ArgoCD
    argocd login "$server" --username admin --password "$password" --insecure
    
    log_success "Logged into ArgoCD successfully!"
}

# Apply ArgoCD project and applications
apply_argocd_resources() {
    log_info "Applying ArgoCD project and applications..."
    
    # Apply the project first
    kubectl apply -f ../argocd/golang-ha-project.yaml
    
    # Wait a moment for the project to be processed
    sleep 5
    
    # Apply the applications
    kubectl apply -f ../argocd/golang-app-application.yaml
    
    log_success "ArgoCD resources applied successfully!"
}

# Setup repository in ArgoCD
setup_repository() {
    log_info "Setting up Git repository in ArgoCD..."
    
    # Check if repository already exists
    if argocd repo list | grep -q "${GIT_REPO_URL}"; then
        log_warning "Repository already exists in ArgoCD"
        return 0
    fi
    
    # Add repository (public repo, no credentials needed)
    argocd repo add "${GIT_REPO_URL}" --name golang-ha-repo
    
    log_success "Repository added to ArgoCD!"
}

# Verify applications
verify_applications() {
    log_info "Verifying ArgoCD applications..."
    
    # List applications
    argocd app list
    
    # Check application status
    local apps=("golang-ha-app" "golang-ha-istio" "golang-ha-security")
    
    for app in "${apps[@]}"; do
        if argocd app get "$app" > /dev/null 2>&1; then
            log_success "Application $app found"
            
            # Show sync status
            local sync_status
            sync_status=$(argocd app get "$app" -o json | jq -r '.status.sync.status')
            log_info "  Sync Status: $sync_status"
            
            # Show health status
            local health_status
            health_status=$(argocd app get "$app" -o json | jq -r '.status.health.status')
            log_info "  Health Status: $health_status"
        else
            log_warning "Application $app not found"
        fi
    done
}

# Sync applications
sync_applications() {
    log_info "Syncing ArgoCD applications..."
    
    local apps=("golang-ha-app" "golang-ha-istio")
    
    for app in "${apps[@]}"; do
        if argocd app get "$app" > /dev/null 2>&1; then
            log_info "Syncing application: $app"
            argocd app sync "$app" --prune
            
            # Wait for sync to complete
            argocd app wait "$app" --timeout 300
            
            log_success "Application $app synced successfully!"
        else
            log_warning "Application $app not found, skipping sync"
        fi
    done
    
    # Note: Security app requires manual sync for safety
    log_warning "Security application requires manual approval for sync"
}

# Setup monitoring for ArgoCD
setup_monitoring() {
    log_info "Setting up ArgoCD monitoring..."
    
    # Apply ServiceMonitor if Prometheus is available
    if kubectl get crd servicemonitors.monitoring.coreos.com > /dev/null 2>&1; then
        kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: ${ARGOCD_NAMESPACE}
  labels:
    app.kubernetes.io/part-of: argocd
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
EOF
        log_success "ArgoCD monitoring configured!"
    else
        log_warning "Prometheus CRDs not found, skipping monitoring setup"
    fi
}

# Cleanup function
cleanup() {
    local pf_pid="$1"
    if [ -n "$pf_pid" ] && kill -0 "$pf_pid" 2>/dev/null; then
        log_info "Cleaning up port-forward..."
        kill "$pf_pid"
    fi
}

# Display access information
display_access_info() {
    local password="$1"
    
    log_success "=========================================="
    log_success "ArgoCD Setup Complete!"
    log_success "=========================================="
    echo
    log_info "Access Information:"
    echo "  Web UI: https://localhost:8080"
    echo "  Username: admin"
    echo "  Password: $password"
    echo
    log_info "ArgoCD CLI Commands:"
    echo "  List apps: argocd app list"
    echo "  Sync app:  argocd app sync <app-name>"
    echo "  Get app:   argocd app get <app-name>"
    echo
    log_info "Applications Configured:"
    echo "  - golang-ha-app: Main application deployment"
    echo "  - golang-ha-istio: Service mesh configuration"
    echo "  - golang-ha-security: Security policies (manual sync)"
    echo
    log_warning "Note: Keep the port-forward running to access ArgoCD UI"
    log_warning "Press Ctrl+C to stop the port-forward when done"
}

# Main function
main() {
    log_info "Starting ArgoCD GitOps setup..."
    
    # Validate environment
    if [ "$PROJECT_ID" = "YOUR_PROJECT_ID" ]; then
        log_error "Please set PROJECT_ID environment variable"
        exit 1
    fi
    
    # Setup
    check_prerequisites
    connect_to_cluster
    
    # Wait for ArgoCD to be ready (assumes Terraform has deployed it)
    wait_for_argocd
    
    # Get admin password
    local password
    password=$(get_argocd_password)
    
    # Setup port forwarding
    local pf_pid
    pf_pid=$(setup_port_forward)
    
    # Setup trap to cleanup on exit
    trap "cleanup $pf_pid" EXIT
    
    # Login and configure
    login_to_argocd "$password"
    setup_repository
    apply_argocd_resources
    
    # Setup monitoring
    setup_monitoring
    
    # Wait a moment for applications to be created
    sleep 10
    
    # Verify and sync
    verify_applications
    sync_applications
    
    # Display access information
    display_access_info "$password"
    
    # Keep port-forward running
    wait
}

# Run main function
main "$@"
