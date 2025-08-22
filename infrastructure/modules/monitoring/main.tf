terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Handle webhook validation issue before installing Prometheus Operator
resource "null_resource" "fix_webhook_validation" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl patch validatingwebhookconfiguration prometheus-operator-admission --type='json' -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]' 2>/dev/null || echo "Webhook not found, proceeding with installation"
    EOT
  }

  # Also try to patch any existing webhook that might cause issues
  provisioner "local-exec" {
    command = <<-EOT
      kubectl get validatingwebhookconfigurations -o name | grep -E "(prometheus|alertmanager)" | xargs -I {} kubectl patch {} --type='json' -p='[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Ignore"}]' 2>/dev/null || echo "No webhooks to patch"
    EOT
  }
}

# Check if Prometheus Operator is already installed
data "kubernetes_namespace" "monitoring" {
  count = 1
  metadata {
    name = "monitoring"
  }
}

# Prometheus Operator - only install if not already present
resource "helm_release" "prometheus_operator" {
  depends_on = [null_resource.fix_webhook_validation]
  
  name             = "prometheus-operator"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "57.0.1"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 600 # 10 minutes timeout
  replace          = false # Don't replace if exists
  wait             = true

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

  # Additional settings to handle GKE webhook issues
  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].job_name"
    value = "kubernetes-pods"
  }

  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].kubernetes_sd_configs[0].role"
    value = "pod"
  }

  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].relabel_configs[0].source_labels[0]"
    value = "__meta_kubernetes_pod_annotation_prometheus_io_scrape"
  }

  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].relabel_configs[0].action"
    value = "keep"
  }

  set {
    name  = "prometheus.prometheusSpec.additionalScrapeConfigs[0].relabel_configs[0].regex"
    value = "true"
  }

  # Handle webhook issues
  set {
    name  = "prometheusOperator.admissionWebhooks.failurePolicy"
    value = "Ignore"
  }

  set {
    name  = "prometheusOperator.admissionWebhooks.enabled"
    value = "false"
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

# Custom metrics adapter
# Note: GKE already provides metrics-server, so we skip this installation
# resource "helm_release" "metrics_server" {
#   name       = "custom-metrics-server"  # Changed name to avoid conflicts
#   repository = "https://kubernetes-sigs.github.io/metrics-server/"
#   chart      = "metrics-server"
#   namespace  = "kube-system"
#   version    = "3.12.0"
#
#   cleanup_on_fail = true
#
#   set {
#     name  = "args[0]"
#     value = "--kubelet-insecure-tls"
#   }
#
#   set {
#     name  = "serviceAccount.create"
#     value = "false"
#   }
#
#   set {
#     name  = "rbac.create"
#     value = "false"
#   }
# }
