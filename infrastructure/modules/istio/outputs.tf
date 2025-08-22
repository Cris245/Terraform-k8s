output "istio_ingress_gateway_ip" {
  description = "External IP of the Istio Ingress Gateway"
  value       = "istio-ingressgateway.istio-system.svc.cluster.local"
}
