# -----------------------------------------------------------------------------
# GCP PROJECT & REGION
# -----------------------------------------------------------------------------
variable "gcp_project_id" {
  description = "The GCP Project ID to deploy resources into."
  type        = string
  default     = "core-infra-labs"
}

variable "gcp_region" {
  description = "The GCP region to deploy resources into."
  type        = string
  default     = "asia-southeast2"
}

variable "gcp_zone" {
  description = "The GCP zone to deploy resources into."
  type        = string
  default     = "asia-southeast2-a"
}

# -----------------------------------------------------------------------------
# CLUSTER CONFIGURATION
# -----------------------------------------------------------------------------
variable "cluster_name" {
  description = "Name prefix for all resources (VPC, instances, firewall rules)."
  type        = string
  default     = "k8s"
}

variable "worker_count" {
  description = "Number of worker nodes to create."
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# COMPUTE CONFIGURATION
# -----------------------------------------------------------------------------
variable "instance_type" {
  description = "The machine type for the K8s nodes."
  type        = string
  default     = "e2-medium"
}

variable "boot_disk_size" {
  description = "Size of the boot disk in GB."
  type        = number
  default     = 30
}

variable "boot_disk_image" {
  description = "The boot disk image for the nodes."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "use_spot_instances" {
  description = "Whether to use spot/preemptible instances for master/workers (cheaper but can be terminated). Jumpbox is always on-demand."
  type        = bool
  default     = true
}

variable "jumpbox_instance_type" {
  description = "Machine type for the jumpbox/bastion host (always on-demand)."
  type        = string
  default     = "e2-micro"
}

variable "jumpbox_boot_disk_size" {
  description = "Boot disk size in GB for the jumpbox."
  type        = number
  default     = 10
}

# -----------------------------------------------------------------------------
# NETWORK CONFIGURATION
# -----------------------------------------------------------------------------
variable "subnet_cidr" {
  description = "CIDR range for the K8s subnet."
  type        = string
  default     = "10.10.1.0/24"
}

variable "my_ip" {
  description = "CIDR allowed to SSH to the jumpbox (:22). Use YOUR_PUBLIC_IP/32. Cluster SSH/API stay private (VPC-only)."
  type        = string
  default     = "0.0.0.0/0" # WARNING: opens jumpbox SSH to the world. Prefer YOUR_IP/32.
}

# -----------------------------------------------------------------------------
# SSH CONFIGURATION
# -----------------------------------------------------------------------------
variable "ssh_user" {
  description = "The SSH username for connecting to the instances."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file."
  type        = string
  default     = "~/.ssh/id_rsa"
}
