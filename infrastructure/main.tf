terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  # Uncomment for production use with GCS backend
  # backend "gcs" {
  #   bucket = "terraform-state-golang-ha"
  #   prefix = "terraform/state"
  # }
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
  
  cluster_name    = var.primary_cluster_name
  project_id      = var.project_id
  region          = var.primary_region
  network         = module.vpc.network_name
  subnetwork      = module.vpc.subnetworks[var.primary_region]
  node_pools      = var.node_pools
  
  depends_on = [module.vpc]
}

module "gke_secondary" {
  source = "./modules/gke"
  
  cluster_name    = var.secondary_cluster_name
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

  project_id                 = var.project_id
  primary_cluster            = module.gke_primary.cluster_name
  secondary_cluster = module.gke_secondary.cluster_name

  cluster_endpoint           = "https://${module.gke_primary.endpoint}"
  cluster_ca_certificate     = module.gke_primary.cluster_ca_certificate
  cluster_client_certificate = module.gke_primary.client_certificate
  cluster_client_key         = module.gke_primary.client_key

  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
  }
}

# Note: Istio is already installed on both clusters
# Skipping Istio installation to avoid conflicts with existing installation

# Application deployment on primary cluster
module "application_primary" {
  source = "./modules/application"

  project_id = var.project_id

  cluster_endpoint        = "https://${module.gke_primary.endpoint}"
  cluster_ca_certificate  = module.gke_primary.cluster_ca_certificate
  cluster_client_certificate = module.gke_primary.client_certificate
  cluster_client_key      = module.gke_primary.client_key
  cluster_ready           = module.gke_primary

  depends_on = [module.gke_primary]

  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
  }
}

# Application deployment on secondary cluster
module "application_secondary" {
  source = "./modules/application"

  project_id = var.project_id

  cluster_endpoint        = "https://${module.gke_secondary.endpoint}"
  cluster_ca_certificate  = module.gke_secondary.cluster_ca_certificate
  cluster_client_certificate = module.gke_secondary.client_certificate
  cluster_client_key      = module.gke_secondary.client_key
  cluster_ready           = module.gke_secondary

  depends_on = [module.gke_secondary]

  providers = {
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
  }
}

# ArgoCD for GitOps
module "argocd" {
  source = "./modules/argocd"

  project_id                 = var.project_id
  primary_cluster            = module.gke_primary.cluster_name
  secondary_cluster = module.gke_secondary.cluster_name
  domain_name       = var.domain_name

  cluster_endpoint           = "https://${module.gke_primary.endpoint}"
  cluster_ca_certificate     = module.gke_primary.cluster_ca_certificate
  cluster_client_certificate = module.gke_primary.client_certificate
  cluster_client_key         = module.gke_primary.client_key

  # ArgoCD configuration
  argocd_hostname     = "argocd.${var.domain_name}"
  git_repository_url  = var.argocd_git_repository_url
  admin_password      = var.argocd_admin_password
  ha_enabled          = var.argocd_ha_enabled
  enable_ingress      = var.argocd_enable_ingress
  enable_monitoring   = var.argocd_enable_monitoring
  environment         = var.environment
  
  # RBAC groups
  admin_groups     = var.argocd_admin_groups
  developer_groups = var.argocd_developer_groups
  sre_groups       = var.argocd_sre_groups
  
  labels = {
    environment = var.environment
    component   = "gitops"
    managed-by  = "terraform"
    project     = "golang-ha-server"
  }

  providers = {
    kubernetes = kubernetes.primary
    helm       = helm.primary
  }
}


# Audit Logging and Compliance
module "audit_logging" {
  source = "./modules/audit-logging"
  
  project_id   = var.project_id
  project_name = "golang-ha"
  environment  = var.environment
  
  # Audit configuration
  audit_dataset_location   = var.audit_dataset_location
  audit_logs_location      = var.audit_logs_location
  audit_log_retention_days = var.audit_log_retention_days
  
  # Security settings
  enable_alerting          = var.enable_audit_alerting
  failed_auth_threshold    = var.audit_failed_auth_threshold
  notification_channels    = var.audit_notification_channels
  
  # Compliance settings
  compliance_mode              = var.audit_compliance_mode
  enable_data_access_logs      = var.audit_enable_data_access_logs
  enable_admin_activity_logs   = var.audit_enable_admin_activity_logs
  
  # Labels
  labels = {
    environment = var.environment
    component   = "audit-logging"
    managed-by  = "terraform"
    project     = "golang-ha-server"
  }
  
  depends_on = [google_project_service.required_apis]
}
