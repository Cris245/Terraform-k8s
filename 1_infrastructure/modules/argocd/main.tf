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
    time = {
      source = "hashicorp/time"
    }
  }
}

# ArgoCD installation via Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = var.argocd_chart_version

  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt(var.admin_password)
  }

  values = [templatefile("${path.module}/values.yaml", {
    git_repository_url = var.git_repository_url
    domain_name        = var.domain_name
  })]
}

# Wait for ArgoCD to be ready before applying applications
resource "time_sleep" "wait_for_argocd" {
  depends_on      = [helm_release.argocd]
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
          server             = var.argocd_hostname
          insecure           = true
          grpc-web           = true
          grpc-web-root-path = "/"
        }
      }
      current-context = var.argocd_hostname
    })
  }

  type = "Opaque"
}

# ServiceMonitor for Prometheus monitoring
// Removed explicit ServiceMonitor; Helm chart values already support enabling ServiceMonitors.

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
