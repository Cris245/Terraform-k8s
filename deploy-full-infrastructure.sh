#!/bin/bash

# Full Infrastructure Deployment Script
# This script automates the complete deployment of the Golang HA infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
PRIMARY_REGION="europe-west1"
SECONDARY_REGION="europe-west3"
PRIMARY_CLUSTER="golang-ha-primary"
SECONDARY_CLUSTER="golang-ha-secondary"

echo -e "${BLUE}🚀 Starting Full Infrastructure Deployment${NC}"
echo -e "${BLUE}Project: ${PROJECT_ID}${NC}"
echo -e "${BLUE}Primary Cluster: ${PRIMARY_CLUSTER} (${PRIMARY_REGION})${NC}"
echo -e "${BLUE}Secondary Cluster: ${SECONDARY_CLUSTER} (${SECONDARY_REGION})${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Validate prerequisites
echo -e "${BLUE}📋 Step 1: Validating Prerequisites${NC}"
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! command -v istioctl &> /dev/null; then
    print_error "istioctl is not installed"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi

print_status "All prerequisites are installed"

# Step 2: Update terraform.tfvars with correct project ID
echo -e "${BLUE}📋 Step 2: Updating Configuration${NC}"
if [ -f "terraform.tfvars" ]; then
    # Update project ID if it's still a placeholder
    if grep -q "YOUR_PROJECT_ID" terraform.tfvars; then
        sed -i.bak "s/YOUR_PROJECT_ID/$PROJECT_ID/g" terraform.tfvars
        print_status "Updated terraform.tfvars with project ID"
    fi
else
    print_error "terraform.tfvars not found"
    exit 1
fi

# Step 3: Deploy Infrastructure
echo -e "${BLUE}📋 Step 3: Deploying Infrastructure${NC}"
print_status "Applying Terraform configuration..."

# Apply infrastructure in phases to avoid race conditions
terraform apply -auto-approve -target=module.vpc -target=module.gke_primary -target=module.gke_secondary

print_status "Waiting for clusters to be ready..."
sleep 30

# Step 4: Configure kubectl for both clusters
echo -e "${BLUE}📋 Step 4: Configuring kubectl${NC}"
print_status "Configuring kubectl for primary cluster..."
gcloud container clusters get-credentials "$PRIMARY_CLUSTER" --region "$PRIMARY_REGION" --project "$PROJECT_ID"

print_status "Configuring kubectl for secondary cluster..."
gcloud container clusters get-credentials "$SECONDARY_CLUSTER" --region "$SECONDARY_REGION" --project "$PROJECT_ID"

# Step 5: Apply remaining infrastructure
echo -e "${BLUE}📋 Step 5: Applying Remaining Infrastructure${NC}"
print_status "Applying monitoring, ArgoCD, and audit logging..."
terraform apply -auto-approve

# Step 6: Install Istio on both clusters
echo -e "${BLUE}📋 Step 6: Installing Istio${NC}"

# Primary cluster
print_status "Installing Istio on primary cluster..."
kubectl config use-context "gke_${PROJECT_ID}_${PRIMARY_REGION}_${PRIMARY_CLUSTER}"
istioctl install --set profile=default -y

# Secondary cluster
print_status "Installing Istio on secondary cluster..."
kubectl config use-context "gke_${PROJECT_ID}_${SECONDARY_REGION}_${SECONDARY_CLUSTER}"
istioctl install --set profile=default -y

# Step 7: Build and push Docker image
echo -e "${BLUE}📋 Step 7: Building and Pushing Application${NC}"
print_status "Building Docker image..."
cd ../application/golang-server
docker buildx build --platform linux/amd64 -t gcr.io/${PROJECT_ID}/golang-ha-app:latest .
docker push gcr.io/${PROJECT_ID}/golang-ha-app:latest
cd ../../infrastructure

# Step 8: Deploy application to both clusters
echo -e "${BLUE}📋 Step 8: Deploying Application${NC}"

# Primary cluster
print_status "Deploying application to primary cluster..."
kubectl config use-context "gke_${PROJECT_ID}_${PRIMARY_REGION}_${PRIMARY_CLUSTER}"

# Create namespaces
kubectl create namespace golang-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace golang-app-privileged --dry-run=client -o yaml | kubectl apply -f -

# Apply Istio configurations
kubectl apply -f ../application/istio-config/gateway.yaml
kubectl apply -f ../application/istio-config/working-canary-vs.yaml
kubectl apply -f ../application/istio-config/cross-cluster-service-entry.yaml
kubectl apply -f ../application/istio-config/waf/

# Apply application manifests
kubectl apply -f ../application/k8s-manifests/deployment-simple.yaml
kubectl apply -f ../application/k8s-manifests/canary-deployment.yaml
kubectl apply -f ../application/k8s-manifests/golang-app-privileged-namespace.yaml
kubectl apply -f ../application/k8s-manifests/hpa-custom-metrics.yaml
kubectl apply -f ../application/k8s-manifests/service-monitor.yaml

# Secondary cluster
print_status "Deploying application to secondary cluster..."
kubectl config use-context "gke_${PROJECT_ID}_${SECONDARY_REGION}_${SECONDARY_CLUSTER}"

# Create namespaces
kubectl create namespace golang-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace golang-app-privileged --dry-run=client -o yaml | kubectl apply -f -

# Apply Istio configurations
kubectl apply -f ../application/istio-config/gateway.yaml
kubectl apply -f ../application/istio-config/working-canary-vs.yaml
kubectl apply -f ../application/istio-config/cross-cluster-service-entry.yaml
kubectl apply -f ../application/istio-config/waf/

# Apply application manifests
kubectl apply -f ../application/k8s-manifests/deployment-simple.yaml
kubectl apply -f ../application/k8s-manifests/canary-deployment.yaml
kubectl apply -f ../application/k8s-manifests/golang-app-privileged-namespace.yaml
kubectl apply -f ../application/k8s-manifests/hpa-custom-metrics.yaml
kubectl apply -f ../application/k8s-manifests/service-monitor.yaml

# Step 9: Update cross-cluster service entry with correct IPs
echo -e "${BLUE}📋 Step 9: Updating Cross-Cluster Configuration${NC}"

# Get secondary cluster Istio Gateway IP
SECONDARY_GATEWAY_IP=$(kubectl config use-context "gke_${PROJECT_ID}_${SECONDARY_REGION}_${SECONDARY_CLUSTER}" && \
    kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ ! -z "$SECONDARY_GATEWAY_IP" ]; then
    print_status "Secondary cluster Istio Gateway IP: $SECONDARY_GATEWAY_IP"
    
    # Update the service entry with the correct IP
    kubectl config use-context "gke_${PROJECT_ID}_${PRIMARY_REGION}_${PRIMARY_CLUSTER}"
    kubectl patch serviceentry golang-app-secondary-cluster -n golang-app --type='json' -p="[{\"op\": \"replace\", \"path\": \"/spec/addresses/0\", \"value\": \"$SECONDARY_GATEWAY_IP\"}, {\"op\": \"replace\", \"path\": \"/spec/endpoints/0/address\", \"value\": \"$SECONDARY_GATEWAY_IP\"}]"
    
    kubectl config use-context "gke_${PROJECT_ID}_${SECONDARY_REGION}_${SECONDARY_CLUSTER}"
    kubectl patch serviceentry golang-app-secondary-cluster -n golang-app --type='json' -p="[{\"op\": \"replace\", \"path\": \"/spec/addresses/0\", \"value\": \"$SECONDARY_GATEWAY_IP\"}, {\"op\": \"replace\", \"path\": \"/spec/endpoints/0/address\", \"value\": \"$SECONDARY_GATEWAY_IP\"}]"
    
    print_status "Updated cross-cluster service entry with correct IP"
else
    print_warning "Could not get secondary cluster Istio Gateway IP"
fi

# Step 10: Wait for applications to be ready
echo -e "${BLUE}📋 Step 10: Waiting for Applications${NC}"
print_status "Waiting for applications to be ready..."

# Primary cluster
kubectl config use-context "gke_${PROJECT_ID}_${PRIMARY_REGION}_${PRIMARY_CLUSTER}"
kubectl wait --for=condition=available --timeout=300s deployment/golang-app -n golang-app
kubectl wait --for=condition=available --timeout=300s deployment/golang-app-canary -n golang-app-privileged

# Secondary cluster
kubectl config use-context "gke_${PROJECT_ID}_${SECONDARY_REGION}_${SECONDARY_CLUSTER}"
kubectl wait --for=condition=available --timeout=300s deployment/golang-app -n golang-app
kubectl wait --for=condition=available --timeout=300s deployment/golang-app-canary -n golang-app-privileged

# Step 11: Display access information
echo -e "${BLUE}📋 Step 11: Deployment Summary${NC}"

# Get Istio Gateway IPs
PRIMARY_GATEWAY_IP=$(kubectl config use-context "gke_${PROJECT_ID}_${PRIMARY_REGION}_${PRIMARY_CLUSTER}" && \
    kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

SECONDARY_GATEWAY_IP=$(kubectl config use-context "gke_${PROJECT_ID}_${SECONDARY_REGION}_${SECONDARY_CLUSTER}" && \
    kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo ""
echo -e "${BLUE}📊 Cluster Information:${NC}"
echo -e "  Primary Cluster:   ${PRIMARY_CLUSTER} (${PRIMARY_REGION})"
echo -e "  Secondary Cluster: ${SECONDARY_CLUSTER} (${SECONDARY_REGION})"
echo ""
echo -e "${BLUE}🌐 Access Points:${NC}"
echo -e "  Primary Istio Gateway:   http://${PRIMARY_GATEWAY_IP}"
echo -e "  Secondary Istio Gateway: http://${SECONDARY_GATEWAY_IP}"
echo ""
echo -e "${BLUE}🔧 Testing Commands:${NC}"
echo -e "  # Test primary cluster"
echo -e "  curl http://${PRIMARY_GATEWAY_IP}"
echo -e ""
echo -e "  # Test canary deployment"
echo -e "  curl -H 'canary: true' http://${PRIMARY_GATEWAY_IP}"
echo -e ""
echo -e "  # Test secondary cluster"
echo -e "  curl http://${SECONDARY_GATEWAY_IP}"
echo ""
echo -e "${BLUE}📈 Monitoring:${NC}"
echo -e "  Grafana: kubectl port-forward svc/prometheus-operator-grafana 3000:80 -n monitoring"
echo -e "  ArgoCD:  kubectl port-forward svc/argocd-server 8080:443 -n argocd"
echo ""
echo -e "${BLUE}🔍 Troubleshooting:${NC}"
echo -e "  # Check primary cluster status"
echo -e "  kubectl config use-context gke_${PROJECT_ID}_${PRIMARY_REGION}_${PRIMARY_CLUSTER}"
echo -e "  kubectl get pods -n golang-app"
echo -e ""
echo -e "  # Check secondary cluster status"
echo -e "  kubectl config use-context gke_${PROJECT_ID}_${SECONDARY_REGION}_${SECONDARY_CLUSTER}"
echo -e "  kubectl get pods -n golang-app"
echo ""

print_status "Full infrastructure deployment completed successfully!"
