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
