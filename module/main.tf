# main.tf

# -----------------------------------------------------------------------------
# LOCALS
# Computed values and DRY configurations
# -----------------------------------------------------------------------------
locals {
  ssh_public_key  = file(pathexpand(var.ssh_public_key_path))
  ssh_private_key = file(pathexpand(var.ssh_private_key_path))

  common_tags = ["${var.cluster_name}-node"]

  # Scheduling configuration based on spot instance preference
  scheduling = var.use_spot_instances ? {
    automatic_restart           = false
    preemptible                 = true
    provisioning_model          = "SPOT"
    instance_termination_action = "DELETE"
    on_host_maintenance         = "TERMINATE"
  } : {
    automatic_restart           = true
    preemptible                 = false
    provisioning_model          = "STANDARD"
    instance_termination_action = null
    on_host_maintenance         = "MIGRATE"
  }
}

# -----------------------------------------------------------------------------
# NETWORKING
# VPC, Subnet, and Static IP
# -----------------------------------------------------------------------------
resource "google_compute_network" "k8s_vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "k8s_subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.k8s_vpc.id
  region        = var.gcp_region
}

resource "google_compute_address" "k8s_master_static_ip" {
  name   = "${var.cluster_name}-master-static-ip"
  region = var.gcp_region
}

# -----------------------------------------------------------------------------
# SECURITY (FIREWALL RULES)
# -----------------------------------------------------------------------------

# Allow SSH from specified IP range
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.cluster_name}-vpc-allow-ssh"
  network = google_compute_network.k8s_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.my_ip]
  target_tags   = local.common_tags
}

# Allow all internal traffic between nodes within the VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.cluster_name}-vpc-allow-internal"
  network = google_compute_network.k8s_vpc.name

  allow {
    protocol = "all"
  }

  source_ranges = [google_compute_subnetwork.k8s_subnet.ip_cidr_range]
}

# Allow traffic to the Kubernetes API server
resource "google_compute_firewall" "allow_k8s_api" {
  name    = "${var.cluster_name}-vpc-allow-k8s-api"
  network = google_compute_network.k8s_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.cluster_name}-master"]
}

# Allow traffic for NodePort services
resource "google_compute_firewall" "allow_nodeport" {
  name    = "${var.cluster_name}-vpc-allow-nodeport"
  network = google_compute_network.k8s_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.cluster_name}-worker"]
}

# -----------------------------------------------------------------------------
# COMPUTE - MASTER NODE
# -----------------------------------------------------------------------------
resource "google_compute_instance" "k8s_master" {
  name         = "${var.cluster_name}-master"
  machine_type = var.instance_type
  zone         = var.gcp_zone
  tags         = concat(local.common_tags, ["${var.cluster_name}-master"])

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size
    }
  }

  network_interface {
    network    = google_compute_network.k8s_vpc.id
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    access_config {
      nat_ip = google_compute_address.k8s_master_static_ip.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${local.ssh_public_key}"
  }

  scheduling {
    automatic_restart           = local.scheduling.automatic_restart
    preemptible                 = local.scheduling.preemptible
    provisioning_model          = local.scheduling.provisioning_model
    instance_termination_action = local.scheduling.instance_termination_action
    on_host_maintenance         = local.scheduling.on_host_maintenance
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = local.ssh_private_key
    host        = self.network_interface[0].access_config[0].nat_ip
  }

  # Copy the dependency script to the VM
  provisioner "file" {
    source      = "${path.module}/scripts/install-k8s-deps.sh"
    destination = "/tmp/install-k8s-deps.sh"
  }

  # Copy the master init script to the VM
  provisioner "file" {
    source      = "${path.module}/scripts/master-init.sh"
    destination = "/tmp/master-init.sh"
  }

  # Execute the master init script
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install-k8s-deps.sh",
      "sudo chmod +x /tmp/master-init.sh",
      "sudo /tmp/master-init.sh ${var.ssh_user} ${google_compute_address.k8s_master_static_ip.address}"
    ]
  }

  depends_on = [google_compute_firewall.allow_ssh]
}

# -----------------------------------------------------------------------------
# COMPUTE - WORKER NODES
# Uses count for dynamic scaling
# -----------------------------------------------------------------------------
resource "google_compute_instance" "k8s_worker" {
  count = var.worker_count

  name         = "${var.cluster_name}-worker-${count.index + 1}"
  machine_type = var.instance_type
  zone         = var.gcp_zone
  tags         = concat(local.common_tags, ["${var.cluster_name}-worker"])

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size
    }
  }

  network_interface {
    network    = google_compute_network.k8s_vpc.id
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${local.ssh_public_key}"
  }

  scheduling {
    automatic_restart           = local.scheduling.automatic_restart
    preemptible                 = local.scheduling.preemptible
    provisioning_model          = local.scheduling.provisioning_model
    instance_termination_action = local.scheduling.instance_termination_action
    on_host_maintenance         = local.scheduling.on_host_maintenance
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = local.ssh_private_key
    host        = self.network_interface[0].access_config[0].nat_ip
  }

  # Copy the dependency script to the VM
  provisioner "file" {
    source      = "${path.module}/scripts/install-k8s-deps.sh"
    destination = "/tmp/install-k8s-deps.sh"
  }

  # Execute the dependency script on the worker
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install-k8s-deps.sh",
      "sudo /tmp/install-k8s-deps.sh",
    ]
  }

  depends_on = [google_compute_instance.k8s_master]
}
