output "waf_policy_name" {
  description = "Name of the Cloud Armor security policy"
  value       = google_compute_security_policy.waf_policy.name
}

output "waf_policy_id" {
  description = "ID of the Cloud Armor security policy"
  value       = google_compute_security_policy.waf_policy.id
}


