variable "docker_image" {
  description = "Docker image for the Golang application"
  type        = string
  default     = null
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_endpoint" {
  description = "GKE cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  type        = string
}

variable "cluster_client_certificate" {
  description = "GKE cluster client certificate"
  type        = string
}

variable "cluster_client_key" {
  description = "GKE cluster client key"
  type        = string
}

variable "cluster_ready" {
  description = "Dependency to ensure cluster is ready before deploying applications"
  type        = any
  default     = null
}

variable "validate_existing_resources" {
  description = "Whether to validate existing resources before creating new ones"
  type        = bool
  default     = false
}
