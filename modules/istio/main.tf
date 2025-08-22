# Istio Module - Installs Istio service mesh via Terraform
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

# Install Istio using the Istio operator
resource "helm_release" "istio_operator" {
  name       = "istio-operator"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istio-operator"
  namespace  = "istio-system"
  create_namespace = true

  set {
    name  = "operatorNamespace"
    value = "istio-operator"
  }
}

# Create Istio control plane
resource "kubernetes_manifest" "istio_control_plane" {
  depends_on = [helm_release.istio_operator]

  manifest = {
    apiVersion = "install.istio.io/v1alpha1"
    kind       = "IstioOperator"
    metadata = {
      name      = "istio-control-plane"
      namespace = "istio-system"
    }
    spec = {
      profile = "default"
      components = {
        pilot = {
          k8s = {
            resources = {
              requests = {
                cpu    = "500m"
                memory = "2048Mi"
              }
              limits = {
                cpu    = "1000m"
                memory = "4096Mi"
              }
            }
          }
        }
        ingressGateways = [
          {
            name = "istio-ingressgateway"
            enabled = true
            k8s = {
              resources = {
                requests = {
                  cpu    = "500m"
                  memory = "512Mi"
                }
                limits = {
                  cpu    = "1000m"
                  memory = "1024Mi"
                }
              }
              service = {
                ports = [
                  {
                    name = "http2"
                    port = 80
                    targetPort = 8080
                  },
                  {
                    name = "https"
                    port = 443
                    targetPort = 8443
                  }
                ]
              }
            }
          }
        ]
      }
      values = {
        global = {
          proxy = {
            resources = {
              requests = {
                cpu    = "100m"
                memory = "128Mi"
              }
              limits = {
                cpu    = "500m"
                memory = "512Mi"
              }
            }
          }
        }
      }
    }
  }
}

# Wait for Istio to be ready
resource "time_sleep" "wait_for_istio" {
  depends_on = [kubernetes_manifest.istio_control_plane]
  create_duration = "60s"
}
