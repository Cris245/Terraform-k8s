output "global_ip" {
  description = "Global IP address"
  value       = google_compute_global_address.default.address
}

output "load_balancer_url" {
  description = "Load balancer URL"
  value       = "https://${google_compute_global_address.default.address}"
}

output "ssl_certificate_name" {
  description = "SSL certificate name"
  value       = google_compute_managed_ssl_certificate.default.name
}

output "ssl_certificate_id" {
  description = "SSL certificate ID"
  value       = google_compute_managed_ssl_certificate.default.id
}

output "health_check_id" {
  description = "Health check ID"
  value       = google_compute_health_check.default.id
}
