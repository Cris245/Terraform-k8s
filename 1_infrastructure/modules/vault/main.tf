# HashiCorp Vault setup for secrets management
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
        node_id = "node-1"
      }

      service_registration "kubernetes" {}
    EOF
  }

  set {
    name  = "server.ha.raft.enabled"
    value = "true"
  }

  set {
    name  = "server.ha.raft.replicas"
    value = "3"
  }

  timeout = 600
  wait    = true
}

# Vault Service Account
resource "kubernetes_service_account" "vault_auth" {
  metadata {
    name      = "vault-auth"
    namespace = "default"
  }
}

# Vault ClusterRoleBinding
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
