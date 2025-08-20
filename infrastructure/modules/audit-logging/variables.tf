variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "golang-ha"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

# Audit logging configuration
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

variable "audit_dataset_owner" {
  description = "Email of the audit dataset owner"
  type        = string
  default     = ""
}

variable "organization_domain" {
  description = "Organization domain for BigQuery access"
  type        = string
  default     = ""
}

# Secret Manager audit exemptions
variable "secret_exempted_members" {
  description = "List of members exempted from Secret Manager data read audit logs"
  type        = list(string)
  default     = []
  # Example: ["serviceAccount:vault@project.iam.gserviceaccount.com"]
}

# Monitoring and alerting
variable "enable_alerting" {
  description = "Enable monitoring alert policies"
  type        = bool
  default     = true
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

variable "failed_auth_threshold" {
  description = "Threshold for failed authentication alerts (per 5 minutes)"
  type        = number
  default     = 5
}

variable "baseline_timestamp" {
  description = "Baseline timestamp for anomaly detection (YYYY-MM-DD format)"
  type        = string
  default     = "2024-01-01"
}

# Log filtering
variable "log_level" {
  description = "Minimum log level to capture (DEBUG, INFO, WARN, ERROR)"
  type        = string
  default     = "WARN"
  
  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARN, ERROR."
  }
}

variable "include_application_logs" {
  description = "Include application logs in audit trail"
  type        = bool
  default     = true
}

variable "include_infrastructure_logs" {
  description = "Include infrastructure logs in audit trail"
  type        = bool
  default     = true
}

variable "include_security_logs" {
  description = "Include security-specific logs in audit trail"
  type        = bool
  default     = true
}

# Compliance settings
variable "compliance_mode" {
  description = "Compliance mode (basic, extended, strict)"
  type        = string
  default     = "extended"
  
  validation {
    condition     = contains(["basic", "extended", "strict"], var.compliance_mode)
    error_message = "Compliance mode must be one of: basic, extended, strict."
  }
}

variable "enable_data_access_logs" {
  description = "Enable data access audit logs (can be expensive)"
  type        = bool
  default     = false
}

variable "enable_admin_activity_logs" {
  description = "Enable admin activity audit logs"
  type        = bool
  default     = true
}

# Custom log sinks
variable "custom_log_sinks" {
  description = "Additional custom log sinks"
  type = list(object({
    name        = string
    destination = string
    filter      = string
    description = string
  }))
  default = []
}

# Labels and tagging
variable "labels" {
  description = "Labels to apply to audit logging resources"
  type        = map(string)
  default = {
    component  = "audit-logging"
    managed-by = "terraform"
  }
}

# Cost optimization
variable "enable_log_sampling" {
  description = "Enable log sampling to reduce costs"
  type        = bool
  default     = false
}

variable "log_sampling_rate" {
  description = "Log sampling rate (0.0 to 1.0)"
  type        = number
  default     = 0.1
  
  validation {
    condition     = var.log_sampling_rate >= 0.0 && var.log_sampling_rate <= 1.0
    error_message = "Log sampling rate must be between 0.0 and 1.0."
  }
}

# Security settings
variable "encrypt_audit_logs" {
  description = "Encrypt audit logs with customer-managed keys"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID for audit log encryption"
  type        = string
  default     = ""
}
