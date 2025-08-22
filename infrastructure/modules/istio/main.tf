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

# Install Istio using the official Istio Helm charts
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = "istio-system"
  create_namespace = true
}

# Install Istio discovery (istiod)
resource "helm_release" "istio_discovery" {
  name       = "istio-discovery"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = "istio-system"
  create_namespace = true

  depends_on = [helm_release.istio_base]

  set {
    name  = "global.hub"
    value = "docker.io/istio"
  }

  set {
    name  = "global.tag"
    value = "1.27.0"
  }
}

# Install Istio ingress gateway
resource "helm_release" "istio_ingressgateway" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = "istio-system"
  create_namespace = true

  depends_on = [helm_release.istio_discovery]

  set {
    name  = "global.hub"
    value = "docker.io/istio"
  }

  set {
    name  = "global.tag"
    value = "1.27.0"
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
}

# Wait for Istio to be ready
resource "time_sleep" "wait_for_istio" {
  depends_on = [helm_release.istio_ingressgateway]
  create_duration = "60s"
}
