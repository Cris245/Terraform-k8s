output "primary_cluster_name" {
  description = "Primary GKE cluster name"
  value       = module.gke_primary.cluster_name
}

output "secondary_cluster_name" {
  description = "Secondary GKE cluster name"
  value       = module.gke_secondary.cluster_name
}

output "load_balancer_ip" {
  description = "Global load balancer IP"
  value       = module.load_balancer.global_ip
}

output "load_balancer_url" {
  description = "Load balancer URL"
  value       = module.load_balancer.load_balancer_url
}

output "vpc_network" {
  description = "VPC network name"
  value       = module.vpc.network_name
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://localhost:3000"
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://argocd.${var.domain_name}"
}

output "kubectl_commands" {
  description = "Kubectl commands to configure access"
  value = [
    "gcloud container clusters get-credentials ${module.gke_primary.cluster_name} --region ${var.primary_region} --project ${var.project_id}",
    "gcloud container clusters get-credentials ${module.gke_secondary.cluster_name} --region ${var.secondary_region} --project ${var.project_id}"
  ]
}

# WAF outputs
output "waf_security_policy_name" {
  description = "Name of the Cloud Armor security policy"
  value       = module.waf.security_policy_name
}

output "waf_security_policy_id" {
  description = "ID of the Cloud Armor security policy"
  value       = module.waf.security_policy_id
}

output "waf_ssl_policy_name" {
  description = "Name of the SSL policy"
  value       = module.waf.ssl_policy_name
}

output "waf_rules_summary" {
  description = "Summary of configured WAF rules"
  value       = module.waf.waf_rules_summary
}

# Audit logging outputs
output "audit_dataset_id" {
  description = "BigQuery dataset ID for audit logs"
  value       = module.audit_logging.audit_dataset_id
}

output "audit_logs_bucket_name" {
  description = "Cloud Storage bucket name for audit logs"
  value       = module.audit_logging.audit_logs_bucket_name
}

output "audit_dashboard_url" {
  description = "Audit logging dashboard URL"
  value       = module.audit_logging.audit_dashboard_url
}

output "audit_monitoring_urls" {
  description = "Audit monitoring and investigation URLs"
  value       = module.audit_logging.monitoring_urls
}

output "audit_compliance_queries" {
  description = "Pre-built compliance reporting queries"
  value       = module.audit_logging.compliance_queries
}
