# -----------------------------------------------------------------------------
# STAGING ENVIRONMENT
# This file calls the reusable kubeadm module
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# Call the kubeadm module
module "kubeadm_cluster" {
  source = "../../module"

  # GCP Configuration
  gcp_project_id = var.gcp_project_id
  gcp_region     = var.gcp_region
  gcp_zone       = var.gcp_zone

  # Cluster Configuration
  cluster_name = var.cluster_name
  worker_count = var.worker_count

  # Compute Configuration
  instance_type          = var.instance_type
  boot_disk_size         = var.boot_disk_size
  boot_disk_image        = var.boot_disk_image
  use_spot_instances     = var.use_spot_instances
  jumpbox_instance_type  = var.jumpbox_instance_type
  jumpbox_boot_disk_size = var.jumpbox_boot_disk_size

  # Network Configuration
  subnet_cidr = var.subnet_cidr
  my_ip       = var.my_ip

  # SSH Configuration
  ssh_user             = var.ssh_user
  ssh_public_key_path  = var.ssh_public_key_path
  ssh_private_key_path = var.ssh_private_key_path
}

