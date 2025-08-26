# Global IP address
resource "google_compute_global_address" "default" {
  name         = "golang-ha-global-ip"
  project      = var.project_id
  address_type = "EXTERNAL"
}

# Health check
resource "google_compute_health_check" "default" {
  name = "golang-ha-health-check"

  http_health_check {
    port = 8080
    request_path = "/"
  }

  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 3
}

# Backend services for each region
# Note: These will be created after the application is deployed
# resource "google_compute_backend_service" "primary" {
#   name        = "golang-ha-backend-primary"
#   project     = var.project_id
#   protocol    = "HTTP"
#   port_name   = "http"
#   timeout_sec = 30
#   health_checks = [google_compute_health_check.default.id]
# }

# resource "google_compute_backend_service" "secondary" {
#   name        = "golang-ha-backend-secondary"
#   project     = var.project_id
#   protocol    = "HTTP"
#   port_name   = "http"
#   timeout_sec = 30
#   health_checks = [google_compute_health_check.default.id]
# }

# URL map for traffic routing
# Note: This will be configured after the application is deployed
# resource "google_compute_url_map" "default" {
#   name            = "golang-ha-url-map"
#   project         = var.project_id
#   default_service = google_compute_backend_service.primary.id
# }

# HTTPS proxy
# Note: This will be configured after the application is deployed
# resource "google_compute_target_https_proxy" "default" {
#   name             = "golang-ha-https-proxy"
#   project          = var.project_id
#   url_map          = google_compute_url_map.default.id
#   ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
# }

# SSL certificate
resource "google_compute_managed_ssl_certificate" "default" {
  name = "golang-ha-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.domain_name]
  }
}

# Global forwarding rule
# Note: This will be configured after the application is deployed
# resource "google_compute_global_forwarding_rule" "default" {
#   name       = "golang-ha-forwarding-rule"
#   project    = var.project_id
#   target     = google_compute_target_https_proxy.default.id
#   port_range = "443"
#   ip_address = google_compute_global_address.default.address
# }

# HTTP to HTTPS redirect
resource "google_compute_url_map" "https_redirect" {
  name    = "golang-ha-https-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "https_redirect" {
  name    = "golang-ha-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.https_redirect.id
}

resource "google_compute_global_forwarding_rule" "https_redirect" {
  name       = "golang-ha-http-forwarding-rule"
  project    = var.project_id
  target     = google_compute_target_http_proxy.https_redirect.id
  port_range = "80"
  ip_address = google_compute_global_address.default.address
}
