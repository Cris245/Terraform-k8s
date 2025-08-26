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
      echo "Performing cluster health check before central monitoring deployment..."

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

# Grafana with multi-cluster Prometheus datasources
resource "helm_release" "grafana" {
  name             = "grafana-central"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "adminPassword"
    value = "admin123"
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "service.port"
    value = "3000"
  }

  # Configure datasources for both Prometheus instances
  set {
    name  = "datasources[0].name"
    value = "Prometheus-Primary"
  }

  set {
    name  = "datasources[0].type"
    value = "prometheus"
  }

  set {
    name  = "datasources[0].url"
    value = var.primary_prometheus_url
  }

  set {
    name  = "datasources[0].isDefault"
    value = "true"
  }

  set {
    name  = "datasources[1].name"
    value = "Prometheus-Secondary"
  }

  set {
    name  = "datasources[1].type"
    value = "prometheus"
  }

  set {
    name  = "datasources[1].url"
    value = var.secondary_prometheus_url
  }

  set {
    name  = "datasources[1].isDefault"
    value = "false"
  }

  depends_on = [null_resource.cluster_health_check]
}

# Expose Vault service with LoadBalancer for cross-cluster access
resource "kubernetes_service" "vault_external" {
  metadata {
    name      = "vault-external"
    namespace = "vault"
    labels = {
      app = "vault"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/instance" = "vault"
      "app.kubernetes.io/name"     = "vault"
      "component"                  = "server"
    }

    port {
      name        = "http"
      port        = 8200
      target_port = 8200
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }

  depends_on = [helm_release.vault]
}

# HashiCorp Vault for secrets management
resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault"
  create_namespace = true

  set {
    name  = "server.dev.enabled"
    value = "false"
  }

  set {
    name  = "server.ha.enabled"
    value = "true"
  }

  set {
    name  = "server.ha.replicas"
    value = "3"
  }

  set {
    name  = "server.ha.raft.enabled"
    value = "true"
  }

  set {
    name  = "server.ha.raft.replicas"
    value = "3"
  }

  set {
    name  = "server.ha.config"
    value = <<-EOF
      ui = true

      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
      }

      storage "raft" {
        path = "/vault/data"
        node_id = "monitoring-node"
      }

      service_registration "kubernetes" {}
    EOF
  }

  set {
    name  = "ui.enabled"
    value = "true"
  }

  set {
    name  = "ui.serviceType"
    value = "ClusterIP"
  }

  depends_on = [null_resource.cluster_health_check]
}

# Kubernetes Service Account for Vault
resource "kubernetes_service_account" "vault_auth" {
  metadata {
    name      = "vault-auth"
    namespace = "default"
  }
}

# Kubernetes ClusterRoleBinding for Vault
resource "kubernetes_cluster_role_binding" "vault_auth" {
  metadata {
    name = "vault-auth"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_auth.metadata[0].name
    namespace = kubernetes_service_account.vault_auth.metadata[0].namespace
  }
}

# Vault Auth Config
resource "kubernetes_config_map" "vault_auth_config" {
  metadata {
    name      = "vault-auth-config"
    namespace = "default"
  }

  data = {
    "auth-config.yml" = <<-EOF
      path = auth/kubernetes
      type = kubernetes

      config = {
        kubernetes_host = "https://kubernetes.default.svc"
        kubernetes_ca_cert = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        token_reviewer_jwt = "/var/run/secrets/kubernetes.io/serviceaccount/token"
      }
    EOF
  }
}

# Vault Policy for Golang App
resource "kubernetes_config_map" "vault_policy" {
  metadata {
    name      = "vault-policy"
    namespace = "default"
  }

  data = {
    "golang-app-policy.hcl" = <<-EOF
      path "secret/data/golang-app/*" {
        capabilities = ["read"]
      }

      path "secret/data/golang-app/database" {
        capabilities = ["read", "create", "update", "delete"]
      }
    EOF
  }
}

# Wait for Vault to be ready
resource "null_resource" "wait_for_vault" {
  depends_on = [helm_release.vault]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Vault to be ready..."
      until kubectl get pods -n vault --no-headers | grep -q "Running"; do
        echo "Vault not ready yet, waiting 30 seconds..."
        sleep 30
      done
      echo "Vault is ready!"
    EOT
  }
}
