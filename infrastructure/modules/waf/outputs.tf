output "security_policy_id" {
  description = "ID of the Cloud Armor security policy"
  value       = google_compute_security_policy.golang_app_policy.id
}

output "security_policy_name" {
  description = "Name of the Cloud Armor security policy"
  value       = google_compute_security_policy.golang_app_policy.name
}

output "security_policy_self_link" {
  description = "Self link of the Cloud Armor security policy"
  value       = google_compute_security_policy.golang_app_policy.self_link
}

output "ssl_policy_id" {
  description = "ID of the SSL policy"
  value       = google_compute_ssl_policy.golang_app_ssl_policy.id
}

output "ssl_policy_name" {
  description = "Name of the SSL policy"
  value       = google_compute_ssl_policy.golang_app_ssl_policy.name
}

output "ssl_policy_self_link" {
  description = "Self link of the SSL policy"
  value       = google_compute_ssl_policy.golang_app_ssl_policy.self_link
}

output "backend_service_id" {
  description = "ID of the backend service (if created)"
  value       = var.create_backend_service ? google_compute_backend_service.golang_app_backend[0].id : null
}

output "backend_service_name" {
  description = "Name of the backend service (if created)"
  value       = var.create_backend_service ? google_compute_backend_service.golang_app_backend[0].name : null
}

output "backend_service_self_link" {
  description = "Self link of the backend service (if created)"
  value       = var.create_backend_service ? google_compute_backend_service.golang_app_backend[0].self_link : null
}

output "url_map_id" {
  description = "ID of the URL map (if created)"
  value       = var.create_url_map ? google_compute_url_map.golang_app_url_map[0].id : null
}

output "url_map_name" {
  description = "Name of the URL map (if created)"
  value       = var.create_url_map ? google_compute_url_map.golang_app_url_map[0].name : null
}

output "url_map_self_link" {
  description = "Self link of the URL map (if created)"
  value       = var.create_url_map ? google_compute_url_map.golang_app_url_map[0].self_link : null
}

# Useful for monitoring and alerting
output "waf_rules_summary" {
  description = "Summary of configured WAF rules"
  value = {
    rate_limiting_enabled        = true
    rate_limit_requests         = var.rate_limit_requests
    rate_limit_interval         = var.rate_limit_interval
    ban_duration_sec           = var.ban_duration_sec
    blocked_countries_count    = length(var.blocked_countries)
    trusted_ip_ranges_count    = length(var.trusted_ip_ranges)
    blocked_user_agents_count  = length(var.blocked_user_agents)
    adaptive_protection_enabled = var.enable_adaptive_protection
    health_check_throttling    = var.enable_health_check_throttling
    sql_injection_protection   = var.enable_sql_injection_protection
    xss_protection            = var.enable_xss_protection
    lfi_protection            = var.enable_lfi_protection
    rce_protection            = var.enable_rce_protection
    scanner_detection         = var.enable_scanner_detection
    protocol_attack_protection = var.enable_protocol_attack_protection
  }
}
