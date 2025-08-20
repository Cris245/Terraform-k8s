resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
}

resource "google_compute_subnetwork" "subnets" {
  for_each = toset(var.regions)
  
  name          = "${var.network_name}-subnet-${each.value}"
  ip_cidr_range = var.subnet_cidrs[each.value]
  region        = each.value
  network       = google_compute_network.vpc.id
  
  # Enable flow logs for network monitoring
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling       = 0.5
    metadata           = "INCLUDE_ALL_METADATA"
  }
}

# Firewall rules for GKE
resource "google_compute_firewall" "gke_master" {
  name    = "${var.network_name}-gke-master"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }
  
  source_ranges = ["172.16.0.0/12"]
  target_tags   = ["gke-node"]
}

resource "google_compute_firewall" "gke_nodes" {
  name    = "${var.network_name}-gke-nodes"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gke-node"]
}

# Cloud NAT for private GKE nodes
resource "google_compute_router" "router" {
  for_each = toset(var.regions)
  
  name    = "${var.network_name}-router-${each.value}"
  region  = each.value
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  for_each = toset(var.regions)
  
  name                               = "${var.network_name}-nat-${each.value}"
  router                            = google_compute_router.router[each.value].name
  region                            = each.value
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
