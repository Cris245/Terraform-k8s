output "vault_external_ip" {
  description = "External IP of Vault LoadBalancer service"
  value       = kubernetes_service.vault_external.status[0].load_balancer[0].ingress[0].ip
}

output "vault_external_hostname" {
  description = "External hostname of Vault LoadBalancer service"
  value       = kubernetes_service.vault_external.status[0].load_balancer[0].ingress[0].hostname
}

output "grafana_service_name" {
  description = "Name of the Grafana service"
  value       = "grafana-central"
}

output "grafana_namespace" {
  description = "Namespace where Grafana is deployed"
  value       = "monitoring"
}
