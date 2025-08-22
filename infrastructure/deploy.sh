#!/bin/bash

# Exit on error
set -e

# --- Configuration ---
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
PRIMARY_REGION="europe-west1"
SECONDARY_REGION="europe-west3"
PRIMARY_CLUSTER="golang-ha-primary"
SECONDARY_CLUSTER="golang-ha-secondary"

# --- Step 1: Apply Core Infrastructure ---
echo "Applying core GKE infrastructure..."
terraform apply -auto-approve \
  -var="project_id=$PROJECT_ID" \
  -target=module.gke_primary \
  -target=module.gke_secondary

# --- Step 2: Configure Kubectl ---
echo "Fetching kubeconfig for primary cluster..."
gcloud container clusters get-credentials "$PRIMARY_CLUSTER" --region "$PRIMARY_REGION" --project "$PROJECT_ID"

# Add a delay to allow the Kubernetes API to stabilize
echo "Waiting for Kubernetes API to stabilize..."
sleep 30

# --- Step 3: Apply Remaining Infrastructure ---
echo "Applying remaining infrastructure (ArgoCD, Monitoring, etc.)..."
terraform apply -auto-approve \
  -var="project_id=$PROJECT_ID"

echo "Deployment complete!"
