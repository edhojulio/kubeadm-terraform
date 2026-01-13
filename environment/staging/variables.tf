# -----------------------------------------------------------------------------
# VARIABLES
# These are passed through to the module
# -----------------------------------------------------------------------------

variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "gcp_zone" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "worker_count" {
  type = number
}

variable "instance_type" {
  type = string
}

variable "boot_disk_size" {
  type = number
}

variable "boot_disk_image" {
  type = string
}

variable "use_spot_instances" {
  type = bool
}

variable "subnet_cidr" {
  type = string
}

variable "my_ip" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "ssh_private_key_path" {
  type = string
}

