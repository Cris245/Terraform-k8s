variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "primary_region" {
  description = "Primary region"
  type        = string
}

variable "regions" {
  description = "List of regions"
  type        = list(string)
}

variable "subnet_cidrs" {
  description = "Subnet CIDR blocks for each region"
  type        = map(string)
  default = {
    "europe-west1" = "10.0.1.0/24"  # Example: Belgium
    "europe-west3" = "10.0.2.0/24"  # Example: Frankfurt
    "us-central1"  = "10.0.3.0/24"  # Example: Iowa
    "us-west1"     = "10.0.4.0/24"  # Example: Oregon
    "asia-east1"   = "10.0.5.0/24"  # Example: Taiwan
  }
}
