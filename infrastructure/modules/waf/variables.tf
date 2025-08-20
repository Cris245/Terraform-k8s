variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "golang-ha"
}

# Rate limiting configuration
variable "rate_limit_requests" {
  description = "Number of requests allowed per interval"
  type        = number
  default     = 100
}

variable "rate_limit_interval" {
  description = "Time interval in seconds for rate limiting"
  type        = number
  default     = 60
}

variable "ban_duration_sec" {
  description = "Duration in seconds to ban an IP after rate limit exceeded"
  type        = number
  default     = 600
}

# Geographic restrictions
variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
  # Example: ["CN", "RU", "KP"] to block China, Russia, North Korea
}

variable "trusted_ip_ranges" {
  description = "List of trusted IP ranges that bypass WAF rules"
  type        = list(string)
  default     = []
  # Example: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

# User agent blocking
variable "blocked_user_agents" {
  description = "List of user agent patterns to block"
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
    "burpsuite"
  ]
}

# Health check throttling
variable "enable_health_check_throttling" {
  description = "Enable throttling for health check endpoints"
  type        = bool
  default     = true
}

# Adaptive protection (ML-based DDoS)
variable "enable_adaptive_protection" {
  description = "Enable adaptive protection for Layer 7 DDoS defense"
  type        = bool
  default     = true
}

# Backend service configuration
variable "create_backend_service" {
  description = "Whether to create a backend service"
  type        = bool
  default     = false
}

variable "backend_timeout_sec" {
  description = "Backend service timeout in seconds"
  type        = number
  default     = 30
}

variable "backend_neg_id" {
  description = "Network Endpoint Group ID for backend"
  type        = string
  default     = ""
}

variable "health_check_ids" {
  description = "List of health check IDs"
  type        = list(string)
  default     = []
}

variable "waf_log_sampling_rate" {
  description = "Sampling rate for WAF logs (0.0 to 1.0)"
  type        = number
  default     = 0.1
}

# URL map configuration
variable "create_url_map" {
  description = "Whether to create a URL map"
  type        = bool
  default     = false
}

variable "default_backend_service" {
  description = "Default backend service ID for URL map"
  type        = string
  default     = ""
}

variable "allowed_hosts" {
  description = "List of allowed hostnames"
  type        = list(string)
  default     = ["*"]
}

# WAF rule customization
variable "enable_sql_injection_protection" {
  description = "Enable SQL injection protection"
  type        = bool
  default     = true
}

variable "enable_xss_protection" {
  description = "Enable XSS protection"
  type        = bool
  default     = true
}

variable "enable_lfi_protection" {
  description = "Enable Local File Inclusion protection"
  type        = bool
  default     = true
}

variable "enable_rce_protection" {
  description = "Enable Remote Code Execution protection"
  type        = bool
  default     = true
}

variable "enable_scanner_detection" {
  description = "Enable security scanner detection"
  type        = bool
  default     = true
}

variable "enable_protocol_attack_protection" {
  description = "Enable protocol attack protection"
  type        = bool
  default     = true
}

# Custom WAF rules
variable "custom_waf_rules" {
  description = "List of custom WAF rules"
  type = list(object({
    action      = string
    priority    = number
    expression  = string
    description = string
  }))
  default = []
}

# Logging and monitoring
variable "enable_waf_logging" {
  description = "Enable WAF logging"
  type        = bool
  default     = true
}

variable "waf_log_filter" {
  description = "Filter for WAF logs"
  type        = string
  default     = ""
}

# Tags and labels
variable "labels" {
  description = "Labels to apply to WAF resources"
  type        = map(string)
  default = {
    environment = "production"
    component   = "waf"
    managed-by  = "terraform"
  }
}
