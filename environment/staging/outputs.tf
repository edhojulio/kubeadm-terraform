# -----------------------------------------------------------------------------
# OUTPUTS
# Expose the module outputs
# -----------------------------------------------------------------------------

output "master_public_ip" {
  description = "Public IP of the master node"
  value       = module.kubeadm_cluster.master_public_ip
}

output "master_private_ip" {
  description = "Private IP of the master node"
  value       = module.kubeadm_cluster.master_private_ip
}

output "worker_public_ips" {
  description = "Public IPs of all worker nodes"
  value       = module.kubeadm_cluster.worker_public_ips
}

output "worker_private_ips" {
  description = "Private IPs of all worker nodes"
  value       = module.kubeadm_cluster.worker_private_ips
}

output "ssh_command_master" {
  description = "SSH command to connect to master"
  value       = module.kubeadm_cluster.ssh_command_master
}

output "kubeadm_join_command" {
  description = "Command to get the join token"
  value       = module.kubeadm_cluster.kubeadm_join_command
}

