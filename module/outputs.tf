# -----------------------------------------------------------------------------
# OUTPUTS
# -----------------------------------------------------------------------------

output "jumpbox_public_ip" {
  description = "Public IP address of the jumpbox/bastion host."
  value       = google_compute_instance.k8s_jumpbox.network_interface[0].access_config[0].nat_ip
}

output "jumpbox_private_ip" {
  description = "Private IP address of the jumpbox/bastion host."
  value       = google_compute_instance.k8s_jumpbox.network_interface[0].network_ip
}

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

output "ssh_command_jumpbox" {
  description = "SSH command to connect to the jumpbox."
  value       = "ssh ${var.ssh_user}@${google_compute_instance.k8s_jumpbox.network_interface[0].access_config[0].nat_ip}"
}

output "ssh_command_master" {
  description = "SSH command to reach the master via the jumpbox (ProxyJump)."
  value       = "ssh -J ${var.ssh_user}@${google_compute_instance.k8s_jumpbox.network_interface[0].access_config[0].nat_ip} ${var.ssh_user}@${google_compute_instance.k8s_master.network_interface[0].network_ip}"
}

output "kubeadm_join_command" {
  description = "Command to get the kubeadm join token on the master (via jumpbox)."
  value       = "ssh -J ${var.ssh_user}@${google_compute_instance.k8s_jumpbox.network_interface[0].access_config[0].nat_ip} ${var.ssh_user}@${google_compute_instance.k8s_master.network_interface[0].network_ip} 'sudo kubeadm token create --print-join-command'"
}

output "kubectl_tunnel_command" {
  description = "Local port-forward of the Kubernetes API via the jumpbox (then point kubectl at https://127.0.0.1:6443)."
  value       = "ssh -N -L 6443:${google_compute_instance.k8s_master.network_interface[0].network_ip}:6443 ${var.ssh_user}@${google_compute_instance.k8s_jumpbox.network_interface[0].access_config[0].nat_ip}"
}
