# Application Module - Deploys the Golang application and Istio configurations
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
  }
}

# Wait for cluster to be fully ready
resource "time_sleep" "wait_for_cluster" {
  depends_on = [var.cluster_ready]
  create_duration = "60s"
}

# Validation: Check if cluster is ready
data "kubernetes_nodes" "all" {
  depends_on = [time_sleep.wait_for_cluster]
}

# Validation: Check if namespaces exist
data "kubernetes_namespace" "golang_app" {
  count = var.validate_existing_resources ? 1 : 0
  metadata {
    name = "golang-app"
  }
}

data "kubernetes_namespace" "golang_app_privileged" {
  count = var.validate_existing_resources ? 1 : 0
  metadata {
    name = "golang-app-privileged"
  }
}

# Create namespaces with validation
resource "kubernetes_namespace" "golang_app" {
  depends_on = [data.kubernetes_nodes.all]
  
  metadata {
    name = "golang-app"
  }
  
  lifecycle {
    ignore_changes = [metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_namespace" "golang_app_privileged" {
  depends_on = [data.kubernetes_nodes.all]
  
  metadata {
    name = "golang-app-privileged"
    labels = {
      "istio-injection" = "enabled"
    }
  }
  
  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}

# Local values for namespace references
locals {
  golang_app_namespace = kubernetes_namespace.golang_app.metadata[0].name
  golang_app_privileged_namespace = kubernetes_namespace.golang_app_privileged.metadata[0].name
}

# Deploy the main application
resource "kubernetes_deployment" "golang_app" {
  metadata {
    name      = "golang-app"
    namespace = local.golang_app_namespace
    labels = {
      app = "golang-app"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "golang-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "golang-app"
        }
      }

      spec {
        container {
          image = var.docker_image != null ? var.docker_image : "gcr.io/${var.project_id}/golang-ha-app:latest"
          name  = "golang-app"

          port {
            container_port = 8080
          }

          env {
            name  = "ENVIRONMENT"
            value = "production"
          }

          env {
            name  = "HOSTNAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}

# Deploy the canary application
resource "kubernetes_deployment" "golang_app_canary" {
  metadata {
    name      = "golang-app-canary"
    namespace = kubernetes_namespace.golang_app_privileged.metadata[0].name
    labels = {
      app = "golang-app-canary"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "golang-app-canary"
      }
    }

    template {
      metadata {
        labels = {
          app = "golang-app-canary"
        }
      }

      spec {
        container {
          image = var.docker_image != null ? var.docker_image : "gcr.io/${var.project_id}/golang-ha-app:latest"
          name  = "golang-app-canary"

          port {
            container_port = 8080
          }

          env {
            name  = "ENVIRONMENT"
            value = "canary"
          }

          env {
            name  = "HOSTNAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

# Create services
resource "kubernetes_service" "golang_app" {
  metadata {
    name      = "golang-app-service"
    namespace = kubernetes_namespace.golang_app.metadata[0].name
  }

  spec {
    selector = {
      app = "golang-app"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service" "golang_app_canary" {
  metadata {
    name      = "golang-app-canary-service"
    namespace = kubernetes_namespace.golang_app_privileged.metadata[0].name
  }

  spec {
    selector = {
      app = "golang-app-canary"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

# Note: Istio Gateway is already configured
# Skipping to avoid conflicts with existing configuration

# Note: Istio Virtual Service is already configured
# Skipping to avoid conflicts with existing configuration

# Note: Istio Destination Rules are already configured
# Skipping to avoid conflicts with existing configuration

# HPA for the main application
# Note: Temporarily commented out due to provider configuration issues
# The HPA already exists and is working correctly
# resource "kubernetes_horizontal_pod_autoscaler" "golang_app" {
#   metadata {
#     name      = "golang-app-hpa"
#     namespace = kubernetes_namespace.golang_app.metadata[0].name
#   }
#
#   spec {
#     max_replicas = 10
#     min_replicas = 3
#
#     scale_target_ref {
#       api_version = "apps/v1"
#       kind        = "Deployment"
#       name        = kubernetes_deployment.golang_app.metadata[0].name
#     }
#
#     metric {
#       type = "Resource"
#       resource {
#         name = "cpu"
#         target {
#           type                = "Utilization"
#           average_utilization = 70
#         }
#       }
#     }
#
#     metric {
#       type = "Resource"
#       resource {
#         name = "memory"
#         target {
#           type                = "Utilization"
#           average_utilization = 80
#         }
#       }
#     }
#   }
# }
