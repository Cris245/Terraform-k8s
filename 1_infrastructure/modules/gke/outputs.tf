output "cluster_name" {
  description = "The name of the GKE cluster."
  value       = google_container_cluster.primary.name
}

output "endpoint" {
  description = "The endpoint of the GKE cluster."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The cluster CA certificate for the GKE cluster."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "client_certificate" {
  description = "The client certificate for authenticating to the GKE cluster."
  value       = google_container_cluster.primary.master_auth[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "The client key for authenticating to the GKE cluster."
  value       = google_container_cluster.primary.master_auth[0].client_key
  sensitive   = true
}
