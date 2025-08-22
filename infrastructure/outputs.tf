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

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://localhost:3000"
}

# Istio is already installed - you can get the gateway IP with:
# kubectl get svc istio-ingressgateway -n istio-system

# Application outputs
output "primary_application_namespace" {
  description = "Primary cluster application namespace"
  value       = module.application_primary.application_namespace
}

output "secondary_application_namespace" {
  description = "Secondary cluster application namespace"
  value       = module.application_secondary.application_namespace
}

output "primary_application_service" {
  description = "Primary cluster application service"
  value       = module.application_primary.application_service
}

output "secondary_application_service" {
  description = "Secondary cluster application service"
  value       = module.application_secondary.application_service
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
