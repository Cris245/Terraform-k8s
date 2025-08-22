variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "primary_region" {
  description = "Primary GCP region"
  type        = string
  default     = "europe-west1"  # Belgium - closest to Spain
}

variable "secondary_region" {
  description = "Secondary GCP region for failover"
  type        = string
  default     = "europe-west3"  # Frankfurt - good backup option
}

variable "regions" {
  description = "List of regions to deploy resources"
  type        = list(string)
  default     = ["europe-west1", "europe-west3"]
}

variable "node_pools" {
  description = "GKE node pools configuration"
  type = map(object({
    machine_type = string
    node_count   = number
    disk_size_gb = number
    disk_type    = string
    preemptible  = bool
  }))
  default = {
    primary = {
      machine_type = "e2-standard-4"
      node_count   = 3
      disk_size_gb = 50
      disk_type    = "pd-standard"
      preemptible  = false
    }
    secondary = {
      machine_type = "e2-standard-4"
      node_count   = 2
      disk_size_gb = 50
      disk_type    = "pd-standard"
      preemptible  = true
    }
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}


# Audit Logging Configuration
variable "audit_dataset_location" {
  description = "Location for BigQuery audit dataset"
  type        = string
  default     = "EU"  # Aligns with European deployment
}

variable "audit_logs_location" {
  description = "Location for Cloud Storage audit logs bucket"
  type        = string
  default     = "EUROPE-WEST1"
}

variable "audit_log_retention_days" {
  description = "Number of days to retain audit logs"
  type        = number
  default     = 365  # 1 year retention for compliance
}

variable "enable_audit_alerting" {
  description = "Enable audit logging alert policies"
  type        = bool
  default     = true
}

variable "audit_failed_auth_threshold" {
  description = "Threshold for failed authentication alerts (per 5 minutes)"
  type        = number
  default     = 5
}

variable "audit_notification_channels" {
  description = "List of notification channel IDs for audit alerts"
  type        = list(string)
  default     = []
}

variable "audit_compliance_mode" {
  description = "Audit compliance mode (basic, extended, strict)"
  type        = string
  default     = "extended"
}

variable "audit_enable_data_access_logs" {
  description = "Enable data access audit logs (can be expensive)"
  type        = bool
  default     = false
}

variable "audit_enable_admin_activity_logs" {
  description = "Enable admin activity audit logs"
  type        = bool
  default     = true
}

# ArgoCD GitOps Configuration
variable "argocd_git_repository_url" {
  description = "Git repository URL for ArgoCD GitOps"
  type        = string
  default     = "https://github.com/Cris245/Terraform-k8s.git"
}

variable "argocd_admin_password" {
  description = "ArgoCD admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "argocd_ha_enabled" {
  description = "Enable high availability mode for ArgoCD"
  type        = bool
  default     = false  # Keep it simple for demo/interview
}

variable "argocd_enable_ingress" {
  description = "Enable Ingress for ArgoCD server"
  type        = bool
  default     = true
}

variable "argocd_enable_monitoring" {
  description = "Enable Prometheus monitoring for ArgoCD"
  type        = bool
  default     = true
}

variable "argocd_admin_groups" {
  description = "List of groups with ArgoCD admin access"
  type        = list(string)
  default     = ["argocd-admins", "platform-engineering"]
}

variable "argocd_developer_groups" {
  description = "List of groups with ArgoCD developer access"
  type        = list(string)
  default     = ["developers"]
}

variable "argocd_sre_groups" {
  description = "List of groups with ArgoCD SRE access"
  type        = list(string)
  default     = ["sre-team"]
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "golang-ha.example.com"
}

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "enable_argocd" {
  description = "Enable ArgoCD for GitOps"
  type        = bool
  default     = true
}

variable "primary_cluster_name" {
  description = "Name for the primary GKE cluster"
  type        = string
  default     = "golang-ha-primary"
}

variable "secondary_cluster_name" {
  description = "Name for the secondary GKE cluster"
  type        = string
  default     = "golang-ha-secondary"
}
