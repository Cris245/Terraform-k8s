# Prometheus Operator
resource "helm_release" "prometheus_operator" {
  name       = "prometheus-operator"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "grafana.adminPassword"
    value = "admin123"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
    value = "5Gi"
  }
}

# Custom metrics adapter
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}

# Horizontal Pod Autoscaler for Golang app
# Note: HPA will be created via Kubernetes manifests instead of Terraform
# This avoids provider version compatibility issues

# Custom metrics for request rate
# Note: Custom HPA will be created via Kubernetes manifests instead of Terraform
# This avoids provider version compatibility issues

# ServiceMonitor for Golang app
# Note: Will be applied after cluster is ready
# resource "kubernetes_manifest" "golang_service_monitor" {
#   manifest = {
#     apiVersion = "monitoring.coreos.com/v1"
#     kind       = "ServiceMonitor"
#     metadata = {
#       name      = "golang-app-monitor"
#       namespace = "monitoring"
#       labels = {
#         release = "prometheus-operator"
#       }
#     }
#     spec = {
#       selector = {
#         matchLabels = {
#           app = "golang-app"
#         }
#       }
#       endpoints = [
#         {
#           port     = "metrics"
#           interval = "30s"
#           path     = "/metrics"
#         }
#       ]
#     }
#   }
# }

# PrometheusRule for alerts
# Note: Will be applied after cluster is ready
# resource "kubernetes_manifest" "golang_prometheus_rule" {
#   manifest = {
#     apiVersion = "monitoring.coreos.com/v1"
#     kind       = "PrometheusRule"
#     metadata = {
#       name      = "golang-app-rules"
#       namespace = "monitoring"
#       labels = {
#         release = "prometheus-operator"
#         prometheus = "kube-prometheus"
#         role = "alert-rules"
#       }
#     }
#     spec = {
#       groups = [
#         {
#           name = "golang-app"
#           rules = [
#             {
#               alert = "GolangAppHighCPU"
#               expr  = "rate(container_cpu_usage_seconds_total{container=\"golang-app\"}[5m]) > 0.8"
#               for   = "5m"
#               labels = {
#                 severity = "warning"
#               }
#               annotations = {
#                 summary = "Golang app CPU usage is high"
#                 description = "CPU usage is above 80% for 5 minutes"
#               }
#             },
#             {
#               alert = "GolangAppHighMemory"
#               expr  = "rate(container_memory_usage_bytes{container=\"golang-app\"}[5m]) > 0.8"
#               for   = "5m"
#               labels = {
#                 severity = "warning"
#               }
#               annotations = {
#                 summary = "Golang app memory usage is high"
#                 description = "Memory usage is above 80% for 5 minutes"
#               }
#             },
#             {
#               alert = "GolangAppDown"
#               expr  = "up{job=\"golang-app\"} == 0"
#               for   = "1m"
#               labels = {
#                 severity = "critical"
#               }
#               annotations = {
#                 summary = "Golang app is down"
#                 description = "Golang app has been down for more than 1 minute"
#               }
#             }
#           ]
#         }
#       ]
#     }
#   }
# }
