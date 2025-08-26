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

# Health check to ensure cluster is ready before monitoring deployment
resource "null_resource" "cluster_health_check" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "Performing cluster health check before Prometheus deployment..."

      # Check if kubectl can connect
      if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "ERROR: Cannot connect to Kubernetes cluster"
        exit 1
      fi

      # Check if nodes are ready
      echo "Checking node status..."
      if ! kubectl get nodes --no-headers | grep -q "Ready"; then
        echo "ERROR: No nodes are in Ready state"
        exit 1
      fi

      # Check if core system pods are running
      echo "Checking core system pods..."
      if ! kubectl get pods -n kube-system --no-headers | grep -q "Running"; then
        echo "ERROR: Core system pods are not running"
        exit 1
      fi

      echo "Cluster health check passed!"
    EOT
  }
}

# Prometheus Operator with just Prometheus (no Grafana)
resource "helm_release" "prometheus_operator" {
  name             = "prometheus-${var.cluster_type}"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  # Disable Grafana and AlertManager for app clusters
  set {
    name  = "grafana.enabled"
    value = "false"
  }

  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  # Configure Prometheus with cluster-specific settings
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "1Gi"
  }

  # Additional scrape configs for Kubernetes pods
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

  set {
    name  = "prometheusOperator.tls.enabled"
    value = "false"
  }

  set {
    name  = "prometheusOperator.tls.internal.enabled"
    value = "false"
  }

  set {
    name  = "prometheusOperator.web.enableTLS"
    value = "false"
  }

  set {
    name  = "prometheusOperator.admissionWebhooks.patch.enabled"
    value = "false"
  }

  set {
    name  = "prometheusOperator.admissionWebhooks.createSecret"
    value = "false"
  }

  depends_on = [null_resource.cluster_health_check]
}

# Expose Prometheus service with LoadBalancer for cross-cluster access
resource "kubernetes_service" "prometheus_external" {
  metadata {
    name      = "prometheus-${var.cluster_type}-external"
    namespace = "monitoring"
    labels = {
      app = "prometheus"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "prometheus"
      "prometheus"             = "prometheus-${var.cluster_type}-prometheus"
    }

    port {
      name        = "http"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  depends_on = [helm_release.prometheus_operator]
}

# Post-install hook to ensure TLS secret exists if TLS is still enabled
resource "null_resource" "ensure_tls_secret" {
  depends_on = [helm_release.prometheus_operator]

  provisioner "local-exec" {
    command = <<-EOT
      # Check if the TLS secret exists
      if ! kubectl get secret prometheus-operator-kube-p-admission -n monitoring >/dev/null 2>&1; then
        echo "Creating TLS secret for Prometheus operator..."

        # Generate a self-signed certificate
        openssl req -x509 -newkey rsa:4096 -keyout /tmp/key.pem -out /tmp/cert.pem -days 365 -nodes -subj "/CN=localhost" 2>/dev/null

        # Create the secret with correct key names
        kubectl create secret generic prometheus-operator-kube-p-admission \
          --from-file=cert=/tmp/cert.pem \
          --from-file=key=/tmp/key.pem \
          -n monitoring 2>/dev/null || echo "Secret already exists"

        # Clean up temporary files
        rm -f /tmp/cert.pem /tmp/key.pem

        echo "TLS secret created successfully"
      else
        echo "TLS secret already exists"
      fi
    EOT
  }
}
