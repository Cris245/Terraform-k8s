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

# WAF (Cloud Armor) Configuration
variable "waf_rate_limit_requests" {
  description = "Number of requests allowed per interval for WAF rate limiting"
  type        = number
  default     = 100
}

variable "waf_rate_limit_interval" {
  description = "Time interval in seconds for WAF rate limiting"
  type        = number
  default     = 60
}

variable "waf_ban_duration_sec" {
  description = "Duration in seconds to ban an IP after rate limit exceeded"
  type        = number
  default     = 600
}

variable "waf_blocked_countries" {
  description = "List of country codes to block in WAF (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
  # Example: ["CN", "RU", "KP"] to block China, Russia, North Korea
}

variable "waf_trusted_ip_ranges" {
  description = "List of trusted IP ranges that bypass WAF rules"
  type        = list(string)
  default     = []
  # Example: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "waf_blocked_user_agents" {
  description = "List of user agent patterns to block in WAF"
  type        = list(string)
  default = [
    "sqlmap",
    "nikto", 
    "nmap",
    "masscan",
    "zap",
    "w3af",
    "dirbuster",
    "gobuster",
    "dirb",
    "burpsuite",
    "acunetix",
    "nessus"
  ]
}

variable "waf_enable_health_check_throttling" {
  description = "Enable throttling for health check endpoints in WAF"
  type        = bool
  default     = true
}

variable "waf_enable_adaptive_protection" {
  description = "Enable adaptive protection for Layer 7 DDoS defense in WAF"
  type        = bool
  default     = true
}

variable "waf_log_sampling_rate" {
  description = "Sampling rate for WAF logs (0.0 to 1.0)"
  type        = number
  default     = 0.1
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
