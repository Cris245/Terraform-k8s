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
      machine_type = "e2-standard-2"
      node_count   = 3
      disk_size_gb = 50
      disk_type    = "pd-standard"
      preemptible  = false
    }
    secondary = {
      machine_type = "e2-standard-2"
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
