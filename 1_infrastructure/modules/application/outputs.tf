output "application_namespace" {
  description = "Namespace where the application is deployed"
  value       = kubernetes_namespace.golang_app.metadata[0].name
}

output "canary_namespace" {
  description = "Namespace where the canary application is deployed"
  value       = kubernetes_namespace.golang_app_privileged.metadata[0].name
}

output "application_service" {
  description = "Service name for the main application"
  value       = kubernetes_service.golang_app.metadata[0].name
}

output "canary_service" {
  description = "Service name for the canary application"
  value       = kubernetes_service.golang_app_canary.metadata[0].name
}
