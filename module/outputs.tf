# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "master_public_ip" {
  description = "Public IP address of the K8s master node."
  value       = google_compute_instance.k8s_master.network_interface[0].access_config[0].nat_ip
}

output "master_private_ip" {
  description = "Private IP address of the K8s master node."
  value       = google_compute_instance.k8s_master.network_interface[0].network_ip
}

output "worker_public_ips" {
  description = "Public IP addresses of all K8s worker nodes."
  value       = [for worker in google_compute_instance.k8s_worker : worker.network_interface[0].access_config[0].nat_ip]
}

output "worker_private_ips" {
  description = "Private IP addresses of all K8s worker nodes."
  value       = [for worker in google_compute_instance.k8s_worker : worker.network_interface[0].network_ip]
}

output "ssh_command_master" {
  description = "SSH command to connect to the master node."
  value       = "ssh ${var.ssh_user}@${google_compute_instance.k8s_master.network_interface[0].access_config[0].nat_ip}"
}

output "kubeadm_join_command" {
  description = "Command to get the kubeadm join token on the master."
  value       = "ssh ${var.ssh_user}@${google_compute_instance.k8s_master.network_interface[0].access_config[0].nat_ip} 'sudo kubeadm token create --print-join-command'"
}
