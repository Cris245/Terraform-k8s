# Application Module - Deploys the Golang application and Istio configurations
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Create namespaces
resource "kubernetes_namespace" "golang_app" {
  metadata {
    name = "golang-app"
  }
}

resource "kubernetes_namespace" "golang_app_privileged" {
  metadata {
    name = "golang-app-privileged"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

# Deploy the main application
resource "kubernetes_deployment" "golang_app" {
  metadata {
    name      = "golang-app"
    namespace = kubernetes_namespace.golang_app.metadata[0].name
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
          image = var.docker_image
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
          image = var.docker_image
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

# Istio Gateway
resource "kubernetes_manifest" "istio_gateway" {
  depends_on = [kubernetes_namespace.golang_app]

  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "Gateway"
    metadata = {
      name      = "golang-app-gateway"
      namespace = kubernetes_namespace.golang_app.metadata[0].name
    }
    spec = {
      selector = {
        istio = "ingressgateway"
      }
      servers = [
        {
          port = {
            number   = 80
            name     = "http"
            protocol = "HTTP"
          }
          hosts = ["*"]
        },
        {
          port = {
            number   = 443
            name     = "https"
            protocol = "HTTPS"
          }
          tls = {
            mode           = "SIMPLE"
            credentialName = "golang-app-tls"
          }
          hosts = ["*"]
        }
      ]
    }
  }
}

# Istio Virtual Service
resource "kubernetes_manifest" "istio_virtual_service" {
  depends_on = [kubernetes_namespace.golang_app, kubernetes_manifest.istio_gateway]

  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "VirtualService"
    metadata = {
      name      = "golang-app-working-canary"
      namespace = kubernetes_namespace.golang_app.metadata[0].name
    }
    spec = {
      hosts    = ["*"]
      gateways = ["golang-app-gateway"]
      http = [
        {
          match = [
            {
              headers = {
                canary = {
                  exact = "true"
                }
              }
            }
          ]
          route = [
            {
              destination = {
                host = "golang-app-canary-service.golang-app-privileged.svc.cluster.local"
                port = {
                  number = 80
                }
              }
              weight = 100
            }
          ]
          timeout = "10s"
          retries = {
            attempts = 3
            perTryTimeout = "2s"
          }
        },
        {
          match = [
            {
              uri = {
                prefix = "/"
              }
            }
          ]
          route = [
            {
              destination = {
                host = "golang-app-service"
                port = {
                  number = 80
                }
              }
              weight = 80
            },
            {
              destination = {
                host = "golang-app-canary-service.golang-app-privileged.svc.cluster.local"
                port = {
                  number = 80
                }
              }
              weight = 20
            }
          ]
          timeout = "10s"
          retries = {
            attempts = 3
            perTryTimeout = "2s"
          }
          corsPolicy = {
            allowOrigins = [
              {
                exact = "*"
              }
            ]
            allowMethods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
            allowHeaders = ["*"]
          }
        }
      ]
    }
  }
}

# Istio Destination Rules
resource "kubernetes_manifest" "istio_destination_rule_stable" {
  depends_on = [kubernetes_namespace.golang_app]

  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "DestinationRule"
    metadata = {
      name      = "golang-app-stable-dr"
      namespace = kubernetes_namespace.golang_app.metadata[0].name
    }
    spec = {
      host = "golang-app-service"
      trafficPolicy = {
        loadBalancer = {
          simple = "ROUND_ROBIN"
        }
        connectionPool = {
          tcp = {
            maxConnections = 100
            connectTimeout = "30ms"
          }
          http = {
            http1MaxPendingRequests = 1024
            maxRequestsPerConnection = 10
            maxRetries = 3
          }
        }
        outlierDetection = {
          consecutive5xxErrors = 5
          interval = "10s"
          baseEjectionTime = "30s"
          maxEjectionPercent = 10
        }
      }
    }
  }
}

resource "kubernetes_manifest" "istio_destination_rule_canary" {
  depends_on = [kubernetes_namespace.golang_app_privileged]

  manifest = {
    apiVersion = "networking.istio.io/v1beta1"
    kind       = "DestinationRule"
    metadata = {
      name      = "golang-app-canary-dr"
      namespace = kubernetes_namespace.golang_app.metadata[0].name
    }
    spec = {
      host = "golang-app-canary-service.golang-app-privileged.svc.cluster.local"
      trafficPolicy = {
        loadBalancer = {
          simple = "ROUND_ROBIN"
        }
        connectionPool = {
          tcp = {
            maxConnections = 50
            connectTimeout = "30ms"
          }
          http = {
            http1MaxPendingRequests = 512
            maxRequestsPerConnection = 5
            maxRetries = 3
          }
        }
        outlierDetection = {
          consecutive5xxErrors = 3
          interval = "10s"
          baseEjectionTime = "30s"
          maxEjectionPercent = 50
        }
      }
    }
  }
}

# HPA for the main application
resource "kubernetes_horizontal_pod_autoscaler" "golang_app" {
  metadata {
    name      = "golang-app-hpa"
    namespace = kubernetes_namespace.golang_app.metadata[0].name
  }

  spec {
    max_replicas = 10
    min_replicas = 3

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.golang_app.metadata[0].name
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}
