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

variable "instance_type" {
  description = "The machine type for the K8s nodes."
  type        = string
  default     = "e2-medium"
}

variable "my_ip" {
  description = "Your public IP address to allow SSH access."
  type        = string
  default     = "0.0.0.0/0" # WARNING: This allows SSH from anywhere. For production, change to your IP like "123.45.67.89/32"
}