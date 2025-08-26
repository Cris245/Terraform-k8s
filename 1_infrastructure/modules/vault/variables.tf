variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "primary_cluster" {
  description = "Primary GKE cluster name"
  type        = string
}

variable "secondary_cluster" {
  description = "Secondary GKE cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  type        = string
}

variable "cluster_client_certificate" {
  description = "Kubernetes cluster client certificate"
  type        = string
}

variable "cluster_client_key" {
  description = "Kubernetes cluster client key"
  type        = string
}

