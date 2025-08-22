variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "primary_cluster" {
  description = "The name of the primary GKE cluster."
  type        = string
}

variable "secondary_cluster" {
  description = "The name of the secondary GKE cluster."
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  type        = string
  sensitive   = true
}

variable "cluster_client_certificate" {
  description = "Kubernetes cluster client certificate"
  type        = string
  sensitive   = true
}

variable "cluster_client_key" {
  description = "Kubernetes cluster client key"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}
