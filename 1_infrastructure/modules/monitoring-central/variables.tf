variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "primary_prometheus_url" {
  description = "URL of Prometheus in primary cluster"
  type        = string
  default     = "http://prometheus-operated.monitoring.svc.cluster.local:9090"
}

variable "secondary_prometheus_url" {
  description = "URL of Prometheus in secondary cluster"
  type        = string
  default     = "http://prometheus-operated.monitoring.svc.cluster.local:9090"
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
