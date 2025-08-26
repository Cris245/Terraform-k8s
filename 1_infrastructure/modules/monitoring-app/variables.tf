variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "cluster_type" {
  description = "Type of cluster (primary/secondary)"
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
  description = "Kubernetes client certificate"
  type        = string
}

variable "cluster_client_key" {
  description = "Kubernetes client key"
  type        = string
}
