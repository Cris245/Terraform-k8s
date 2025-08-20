# ArgoCD installation via Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = var.argocd_chart_version
  
  # Core server configuration
  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }
  
  # High availability configuration
  set {
    name  = "controller.replicas"
    value = var.ha_enabled ? "2" : "1"
  }
  
  set {
    name  = "server.replicas"
    value = var.ha_enabled ? "2" : "1"
  }
  
  set {
    name  = "repoServer.replicas"
    value = var.ha_enabled ? "2" : "1"
  }
  
  # Redis HA for production
  set {
    name  = "redis-ha.enabled"
    value = var.ha_enabled
  }
  
  set {
    name  = "redis.enabled"
    value = var.ha_enabled ? "false" : "true"
  }
  
  # External access configuration
  set {
    name  = "server.service.type"
    value = var.enable_ingress ? "ClusterIP" : "LoadBalancer"
  }
  
  # Ingress configuration (when using Istio)
  dynamic "set" {
    for_each = var.enable_ingress ? [1] : []
    content {
      name  = "server.ingress.enabled"
      value = "true"
    }
  }
  
  dynamic "set" {
    for_each = var.enable_ingress ? [1] : []
    content {
      name  = "server.ingress.ingressClassName"
      value = "istio"
    }
  }
  
  dynamic "set" {
    for_each = var.enable_ingress ? [1] : []
    content {
      name  = "server.ingress.hosts[0]"
      value = var.argocd_hostname
    }
  }
  
  # RBAC configuration
  set {
    name  = "server.rbacConfig.policy.default"
    value = "role:readonly"
  }
  
  set {
    name  = "server.rbacConfig.scopes"
    value = "[groups]"
  }
  
  # Repository configuration
  set {
    name  = "configs.repositories.golang-ha-repo.url"
    value = var.git_repository_url
  }
  
  set {
    name  = "configs.repositories.golang-ha-repo.type"
    value = "git"
  }
  
  # Admin password (use random password in production)
  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt(var.admin_password)
  }
  
  # Resource limits for production
  set {
    name  = "controller.resources.limits.cpu"
    value = "2000m"
  }
  
  set {
    name  = "controller.resources.limits.memory"
    value = "2Gi"
  }
  
  set {
    name  = "controller.resources.requests.cpu"
    value = "1000m"
  }
  
  set {
    name  = "controller.resources.requests.memory"
    value = "1Gi"
  }
  
  set {
    name  = "server.resources.limits.cpu"
    value = "500m"
  }
  
  set {
    name  = "server.resources.limits.memory"
    value = "512Mi"
  }
  
  set {
    name  = "repoServer.resources.limits.cpu"
    value = "1000m"
  }
  
  set {
    name  = "repoServer.resources.limits.memory"
    value = "1Gi"
  }
  
  # Metrics and monitoring
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }
  
  set {
    name  = "server.metrics.enabled"
    value = "true"
  }
  
  set {
    name  = "repoServer.metrics.enabled"
    value = "true"
  }
  
  # Application controller configuration
  set {
    name  = "controller.args.statusProcessors"
    value = "20"
  }
  
  set {
    name  = "controller.args.operationProcessors"
    value = "10"
  }
  
  set {
    name  = "controller.args.appResyncPeriod"
    value = "180"
  }
  
  # Security settings
  set {
    name  = "global.securityContext.runAsNonRoot"
    value = "true"
  }
  
  set {
    name  = "global.securityContext.runAsUser"
    value = "999"
  }
  
  values = [templatefile("${path.module}/values.yaml", {
    project_id      = var.project_id
    git_repo_url    = var.git_repository_url
    domain_name     = var.domain_name
    enable_ha       = var.ha_enabled
    enable_ingress  = var.enable_ingress
  })]
}

# Wait for ArgoCD to be ready before applying applications
resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]
  create_duration = "60s"
}

# ArgoCD CLI configuration secret
resource "kubernetes_secret" "argocd_cli_config" {
  depends_on = [helm_release.argocd]
  
  metadata {
    name      = "argocd-cli-config"
    namespace = "argocd"
    labels = {
      "app.kubernetes.io/part-of" = "argocd"
    }
  }
  
  data = {
    "config" = yamlencode({
      servers = {
        (var.argocd_hostname) = {
          server                = var.argocd_hostname
          insecure             = true
          grpc-web             = true
          grpc-web-root-path   = "/"
        }
      }
      current-context = var.argocd_hostname
    })
  }
  
  type = "Opaque"
}

# ServiceMonitor for Prometheus monitoring
resource "kubernetes_manifest" "argocd_servicemonitor" {
  count = var.enable_monitoring ? 1 : 0
  depends_on = [helm_release.argocd]
  
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "argocd-metrics"
      namespace = "argocd"
      labels = {
        "app.kubernetes.io/part-of" = "argocd"
        release = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "argocd-metrics"
        }
      }
      endpoints = [
        {
          port = "metrics"
          path = "/metrics"
          interval = "30s"
        }
      ]
    }
  }
}

# ArgoCD Application for Golang app
# Note: Will be applied after cluster is ready
# resource "kubernetes_manifest" "golang_app_application" {
#   manifest = {
#     apiVersion = "argoproj.io/v1alpha1"
#     kind       = "Application"
#     metadata = {
#       name      = "golang-app"
#       namespace = "argocd"
#     }
#     spec = {
#       project = "default"
#       source = {
#         repoURL        = "https://github.com/your-org/golang-ha-app"
#         targetRevision = "main"
#         path          = "k8s"
#       }
#       destination = {
#         server    = "https://kubernetes.default.svc"
#         namespace = "default"
#       }
#       syncPolicy = {
#         automated = {
#           prune      = true
#           selfHeal   = true
#           allowEmpty = false
#         }
#         syncOptions = [
#           "CreateNamespace=true",
#           "PrunePropagationPolicy=foreground",
#           "PruneLast=true"
#         ]
#         retry = {
#           limit = 5
#           backoff = {
#             duration = "5s"
#             factor   = 2
#             maxDuration = "3m"
#           }
#         }
#       }
#       revisionHistoryLimit = 10
#     }
#   }
# }

# ArgoCD Application for monitoring
# Note: Will be applied after cluster is ready
# resource "kubernetes_manifest" "monitoring_application" {
#   manifest = {
#     apiVersion = "argoproj.io/v1alpha1"
#     kind       = "Application"
#     metadata = {
#       name      = "monitoring"
#       namespace = "argocd"
#     }
#     spec = {
#       project = "default"
#       source = {
#         repoURL        = "https://github.com/your-org/golang-ha-app"
#         targetRevision = "main"
#         path          = "monitoring"
#       }
#       destination = {
#         server    = "https://kubernetes.default.svc"
#         namespace = "monitoring"
#       }
#       syncPolicy = {
#         automated = {
#           prune      = true
#           selfHeal   = true
#           allowEmpty = false
#         }
#         syncOptions = [
#           "CreateNamespace=true",
#           "PrunePropagationPolicy=foreground",
#           "PruneLast=true"
#         ]
#         retry = {
#           limit = 5
#           backoff = {
#             duration = "5s"
#             factor   = 2
#             maxDuration = "3m"
#           }
#         }
#       }
#       revisionHistoryLimit = 10
#     }
#   }
# }

# ArgoCD Application for security
# Note: Will be applied after cluster is ready
# resource "kubernetes_manifest" "security_application" {
#   manifest = {
#     apiVersion = "argoproj.io/v1alpha1"
#     kind       = "Application"
#     metadata = {
#       name      = "security"
#       namespace = "argocd"
#     }
#     spec = {
#       project = "default"
#       source = {
#         repoURL        = "https://github.com/your-org/golang-ha-app"
#         targetRevision = "main"
#         path          = "security"
#       }
#       destination = {
#         server    = "https://kubernetes.default.svc"
#         namespace = "security"
#       }
#       syncPolicy = {
#         automated = {
#           prune      = true
#           selfHeal   = true
#           allowEmpty = false
#         }
#         syncOptions = [
#           "CreateNamespace=true",
#           "PrunePropagationPolicy=foreground",
#           "PruneLast=true"
#         ]
#         retry = {
#           limit = 5
#           backoff = {
#             duration = "5s"
#             factor   = 2
#             maxDuration = "3m"
#           }
#         }
#       }
#       revisionHistoryLimit = 10
#     }
#   }
# }
