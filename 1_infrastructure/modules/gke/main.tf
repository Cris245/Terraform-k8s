resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network
  subnetwork = var.subnetwork

  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.region == "europe-west1" ? "172.16.0.0/28" : "172.16.1.0/28"
  }

  # Release channel for automatic updates
  release_channel {
    channel = "REGULAR"
  }
}

# Node pools
resource "google_container_node_pool" "primary_pools" {
  for_each = var.node_pools

  name       = "${var.cluster_name}-${each.key}"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  project    = var.project_id
  version    = google_container_cluster.primary.master_version

  autoscaling {
    min_node_count = each.value.node_count
    max_node_count = each.value.node_count * 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type
    preemptible  = each.value.preemptible

    # Workload Identity metadata config - commented out since Workload Identity is not enabled
    # workload_metadata_config {
    #   mode = "GKE_METADATA"
    # }

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels
    labels = {
      environment = var.environment
      node-pool   = each.key
    }

    # Taints for dedicated node pools
    dynamic "taint" {
      for_each = each.key == "primary" ? [] : [1]
      content {
        key    = "dedicated"
        value  = each.key
        effect = "NO_SCHEDULE"
      }
    }
  }

  # Avoid unnecessary PATCH calls when nothing substantive changed
  lifecycle {
    ignore_changes = [
      node_config,
    ]
  }
}
