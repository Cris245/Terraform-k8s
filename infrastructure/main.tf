terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
  # Uncomment for production use with GCS backend
  # backend "gcs" {
  #   bucket = "terraform-state-golang-ha"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.primary_region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com"
  ])
  
  service = each.value
  disable_on_destroy = false
}

# VPC Network
module "vpc" {
  source = "./modules/vpc"
  
  project_id     = var.project_id
  network_name   = "golang-ha-vpc"
  primary_region = var.primary_region
  regions        = var.regions
  
  depends_on = [google_project_service.required_apis]
}

# GKE Clusters
module "gke_primary" {
  source = "./modules/gke"
  
  cluster_name    = "golang-ha-primary"
  project_id      = var.project_id
  region          = var.primary_region
  network         = module.vpc.network_name
  subnetwork      = module.vpc.subnetworks[var.primary_region]
  node_pools      = var.node_pools
  
  depends_on = [module.vpc]
}

module "gke_secondary" {
  source = "./modules/gke"
  
  cluster_name    = "golang-ha-secondary"
  project_id      = var.project_id
  region          = var.secondary_region
  network         = module.vpc.network_name
  subnetwork      = module.vpc.subnetworks[var.secondary_region]
  node_pools      = var.node_pools
  
  depends_on = [module.vpc]
}

# Load Balancer
module "load_balancer" {
  source = "./modules/load_balancer"
  
  project_id       = var.project_id
  primary_region   = var.primary_region
  secondary_region = var.secondary_region
  primary_cluster  = module.gke_primary.cluster_name
  secondary_cluster = module.gke_secondary.cluster_name
  
  depends_on = [module.gke_primary, module.gke_secondary]
}

# Monitoring Stack
module "monitoring" {
  source = "./modules/monitoring"
  
  project_id = var.project_id
  primary_cluster = module.gke_primary.cluster_name
  secondary_cluster = module.gke_secondary.cluster_name
  
  depends_on = [module.gke_primary, module.gke_secondary]
}

# ArgoCD for GitOps
module "argocd" {
  source = "./modules/argocd"
  
  project_id = var.project_id
  primary_cluster = module.gke_primary.cluster_name
  secondary_cluster = module.gke_secondary.cluster_name
  
  depends_on = [module.gke_primary, module.gke_secondary]
}

# Web Application Firewall (Cloud Armor)
module "waf" {
  source = "./modules/waf"
  
  project_id   = var.project_id
  project_name = "golang-ha"
  
  # Rate limiting configuration
  rate_limit_requests = var.waf_rate_limit_requests
  rate_limit_interval = var.waf_rate_limit_interval
  ban_duration_sec    = var.waf_ban_duration_sec
  
  # Geographic restrictions
  blocked_countries = var.waf_blocked_countries
  trusted_ip_ranges = var.waf_trusted_ip_ranges
  
  # User agent blocking
  blocked_user_agents = var.waf_blocked_user_agents
  
  # Feature toggles
  enable_health_check_throttling = var.waf_enable_health_check_throttling
  enable_adaptive_protection     = var.waf_enable_adaptive_protection
  
  # Logging
  waf_log_sampling_rate = var.waf_log_sampling_rate
  
  # Backend integration (when used with Istio Gateway)
  create_backend_service = false  # We use Istio Gateway instead
  create_url_map        = false   # We use Istio VirtualService instead
  
  # Labels
  labels = {
    environment = var.environment
    component   = "waf"
    managed-by  = "terraform"
    project     = "golang-ha-server"
  }
  
  depends_on = [google_project_service.required_apis]
}
