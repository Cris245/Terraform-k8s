output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "subnetworks" {
  description = "Map of subnetworks by region"
  value       = { for region, subnet in google_compute_subnetwork.subnets : region => subnet.name }
}

output "subnetwork_ids" {
  description = "Map of subnetwork IDs by region"
  value       = { for region, subnet in google_compute_subnetwork.subnets : region => subnet.id }
}
