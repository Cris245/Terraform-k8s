variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "primary_cluster" {
  description = "Primary cluster name"
  type        = string
}

variable "secondary_cluster" {
  description = "Secondary cluster name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for ArgoCD"
  type        = string
  default     = "golang-ha.example.com"
}

# ArgoCD configuration
variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.46.8"  # Latest stable version
}

variable "argocd_hostname" {
  description = "Hostname for ArgoCD server"
  type        = string
  default     = "argocd.golang-ha.example.com"
}

variable "git_repository_url" {
  description = "Git repository URL for GitOps"
  type        = string
  default     = "https://github.com/Cris245/Terraform-k8s.git"
}

variable "admin_password" {
  description = "ArgoCD admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

variable "ha_enabled" {
  description = "Enable high availability mode for ArgoCD"
  type        = bool
  default     = false  # Simple single instance for demo
}

variable "enable_ingress" {
  description = "Enable Ingress for ArgoCD server"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable Prometheus monitoring for ArgoCD"
  type        = bool
  default     = true
}

variable "enable_notifications" {
  description = "Enable ArgoCD notifications"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# RBAC configuration
variable "admin_groups" {
  description = "List of groups with admin access"
  type        = list(string)
  default     = ["argocd-admins"]
}

variable "developer_groups" {
  description = "List of groups with developer access"
  type        = list(string)
  default     = ["developers"]
}

variable "sre_groups" {
  description = "List of groups with SRE access"
  type        = list(string)
  default     = ["sre-team"]
}

# Resource limits
variable "controller_resources" {
  description = "Resource limits for ArgoCD controller"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "1000m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "2Gi"
    }
  }
}

variable "server_resources" {
  description = "Resource limits for ArgoCD server"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "250m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "repo_server_resources" {
  description = "Resource limits for ArgoCD repo server"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

# Additional repositories
variable "additional_repositories" {
  description = "Additional Git repositories for ArgoCD"
  type = list(object({
    url  = string
    name = string
    type = string
  }))
  default = []
}

# Sync policies
variable "sync_policy" {
  description = "Default sync policy for applications"
  type = object({
    automated = object({
      prune       = bool
      self_heal   = bool
      allow_empty = bool
    })
    sync_options = list(string)
    retry = object({
      limit = number
      backoff = object({
        duration     = string
        factor       = number
        max_duration = string
      })
    })
  })
  default = {
    automated = {
      prune       = true
      self_heal   = true
      allow_empty = false
    }
    sync_options = [
      "CreateNamespace=true",
      "PrunePropagationPolicy=foreground",
      "PruneLast=true",
      "ApplyOutOfSyncOnly=true"
    ]
    retry = {
      limit = 5
      backoff = {
        duration     = "5s"
        factor       = 2
        max_duration = "3m"
      }
    }
  }
}

# Labels
variable "labels" {
  description = "Labels to apply to ArgoCD resources"
  type        = map(string)
  default = {
    component  = "gitops"
    managed-by = "terraform"
  }
}
