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

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}
