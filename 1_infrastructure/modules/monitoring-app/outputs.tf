output "prometheus_external_ip" {
  description = "External IP of Prometheus LoadBalancer service"
  value       = kubernetes_service.prometheus_external.status[0].load_balancer[0].ingress[0].ip
}

output "prometheus_external_hostname" {
  description = "External hostname of Prometheus LoadBalancer service"
  value       = kubernetes_service.prometheus_external.status[0].load_balancer[0].ingress[0].hostname
}
