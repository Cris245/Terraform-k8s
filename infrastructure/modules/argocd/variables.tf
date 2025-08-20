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
