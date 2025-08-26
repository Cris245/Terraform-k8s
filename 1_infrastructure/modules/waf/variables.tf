variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "waf_policy_name" {
  description = "Name for the WAF policy"
  type        = string
  default     = "golang-ha-waf-policy"
}

variable "waf_enable_ddos_protection" {
  description = "Enable DDoS protection"
  type        = bool
  default     = true
}

variable "waf_enable_owasp_rules" {
  description = "Enable OWASP rules"
  type        = bool
  default     = true
}

variable "waf_enable_geo_blocking" {
  description = "Enable geographic blocking"
  type        = bool
  default     = false
}


