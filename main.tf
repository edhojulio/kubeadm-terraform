# main.tf

# -----------------------------------------------------------------------------
# LOGICAL MODULE: NETWORKING
# This section defines the VPC and Subnet.
# -----------------------------------------------------------------------------
resource "google_compute_network" "k8s_vpc" {
  name                    = "k8s-vpc"
  auto_create_subnetworks = false # We want full control, so we create subnets manually
}

resource "google_compute_subnetwork" "k8s_subnet" {
  name          = "k8s-subnet"
  ip_cidr_range = "10.10.1.0/24"
  network       = google_compute_network.k8s_vpc.id
  region        = var.gcp_region
}

resource "google_compute_address" "k8s_master_static_ip" {
  name   = "k8s-master-static-ip"
  region = var.gcp_region
}

# -----------------------------------------------------------------------------
# LOGICAL MODULE: SECURITY (FIREWALL RULES)
# This section defines firewall rules using network tags.
# -----------------------------------------------------------------------------

# Allow SSH from your specific IP (or anywhere for this demo)
resource "google_compute_firewall" "allow_ssh" {
  name    = "k8s-vpc-allow-ssh"
  network = google_compute_network.k8s_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = [var.my_ip]
  target_tags   = ["k8s-node"] # Apply to all our nodes
}

# Allow all internal traffic between nodes within the VPC for cluster communication
resource "google_compute_firewall" "allow_internal" {
  name    = "k8s-vpc-allow-internal"
  network = google_compute_network.k8s_vpc.name
  allow {
    protocol = "all"
  }
  source_ranges = [google_compute_subnetwork.k8s_subnet.ip_cidr_range]
}

# Allow traffic to the Kubernetes API server from anywhere (for kubectl)
resource "google_compute_firewall" "allow_k8s_api" {
  name    = "k8s-vpc-allow-k8s-api"
  network = google_compute_network.k8s_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["k8s-master"] # Apply only to the master node
}

# Allow traffic for NodePort services
resource "google_compute_firewall" "allow_nodeport" {
  name    = "k8s-vpc-allow-nodeport"
  network = google_compute_network.k8s_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["k8s-worker"] # Apply to worker nodes
}

# -----------------------------------------------------------------------------
# LOGICAL MODULE: COMPUTE (VIRTUAL MACHINES)
# This section defines the master and worker nodes.
# -----------------------------------------------------------------------------

resource "google_compute_instance" "k8s_master" {
  name         = "k8s-master"
  machine_type = var.instance_type
  zone         = var.gcp_zone
  tags         = ["k8s-node", "k8s-master"]


  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30 # GB
    }
  }

  network_interface {
    network    = google_compute_network.k8s_vpc.id
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    # This access_config block assigns a public IP to the VM
    access_config {
      nat_ip = google_compute_address.k8s_master_static_ip.address
    }
  }

  metadata = {
    ssh-keys = "edhojulio:${file("/Users/edhojulio/.ssh/id_rsa.pub")}"
  }

  scheduling {
    automatic_restart           = false
    preemptible                 = true
    provisioning_model          = "SPOT"
    instance_termination_action = "DELETE"
    on_host_maintenance         = "TERMINATE"
  }

  // Copy the dependency script to the VM
  provisioner "file" {
    source      = "scripts/install-k8s-deps.sh"
    destination = "/tmp/install-k8s-deps.sh"

    connection {
      type = "ssh"
      user = "edhojulio"
      #private_key = "${file(path.expand("~/.ssh/id_rsa"))}"
      private_key = file("/Users/edhojulio/.ssh/id_rsa")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  // Copy the master init script to the VM
  provisioner "file" {
    source      = "scripts/master-init.sh"
    destination = "/tmp/master-init.sh"

    connection {
      type = "ssh"
      user = "edhojulio"
      #private_key = "${file(path.expand("~/.ssh/id_rsa"))}"
      private_key = file("/Users/edhojulio/.ssh/id_rsa")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  // Execute the master init script
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install-k8s-deps.sh",
      "sudo chmod +x /tmp/master-init.sh",
      "sudo /tmp/master-init.sh"
    ]
  }

    connection {
      type = "ssh"
      user = "edhojulio"
      #private_key = "${file(path.expand("~/.ssh/id_rsa"))}"
      private_key = file("/Users/edhojulio/.ssh/id_rsa")
      host        = self.network_interface[0].access_config[0].nat_ip
    }

  # Ensure scripts run after instance creation
  depends_on = [
    google_compute_firewall.allow_ssh
  ]
}

resource "google_compute_instance" "k8s_worker_1" {
  name         = "k8s-worker-1"
  machine_type = var.instance_type
  zone         = var.gcp_zone
  tags         = ["k8s-node", "k8s-worker"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30 # GB
    }
  }

  network_interface {
    network    = google_compute_network.k8s_vpc.id
    subnetwork = google_compute_subnetwork.k8s_subnet.id
    access_config {}
  }

  scheduling {
    automatic_restart           = false
    preemptible                 = true
    provisioning_model          = "SPOT"
    instance_termination_action = "DELETE"
    on_host_maintenance         = "TERMINATE"
  }

  // Copy the dependency script to the VM
  provisioner "file" {
    source      = "scripts/install-k8s-deps.sh"
    destination = "/tmp/install-k8s-deps.sh"

    connection {
      type = "ssh"
      user = "edhojulio"
      #private_key = "${file(path.expand("~/.ssh/id_rsa"))}"
      private_key = file("/Users/edhojulio/.ssh/id_rsa")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  // Execute ONLY the dependency script on the worker
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install-k8s-deps.sh",
      "sudo /tmp/install-k8s-deps.sh",
    ]
    connection {
      type = "ssh"
      user = "edhojulio"
      #private_key = "${file(path.expand("~/.ssh/id_rsa"))}"
      private_key = file("/Users/edhojulio/.ssh/id_rsa")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  connection {
    type        = "ssh"
    user        = "edhojulio"
    #private_key = file(path.expand("~/.ssh/id_rsa"))
    private_key = file("Users/edhojulio/.ssh/id_rsa")
    host        = self.network_interface[0].access_config[0].nat_ip
  }

  depends_on = [
    google_compute_instance.k8s_master
  ]
}
