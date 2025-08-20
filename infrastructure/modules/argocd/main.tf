# ArgoCD installation
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true

  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }

  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.ingressClassName"
    value = "nginx"
  }

  set {
    name  = "server.ingress.hosts[0]"
    value = "argocd.${var.domain_name}"
  }

  set {
    name  = "server.ingress.tls[0].secretName"
    value = "argocd-tls"
  }

  set {
    name  = "server.ingress.tls[0].hosts[0]"
    value = "argocd.${var.domain_name}"
  }

  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt("admin123")
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
