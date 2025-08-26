provider "google" {
  project = var.project_id
}

data "google_client_config" "default" {}

# Provider for primary cluster
provider "kubernetes" {
  alias                  = "primary"
  host                   = "https://${module.gke_primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke_primary.cluster_ca_certificate)
}

provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = "https://${module.gke_primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke_primary.cluster_ca_certificate)
  }
}

# Provider for secondary cluster
provider "kubernetes" {
  alias                  = "secondary"
  host                   = "https://${module.gke_secondary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke_secondary.cluster_ca_certificate)
}

provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = "https://${module.gke_secondary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke_secondary.cluster_ca_certificate)
  }
}
