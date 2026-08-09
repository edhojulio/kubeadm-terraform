# -----------------------------------------------------------------------------
# OUTPUTS
# Expose the module outputs
# -----------------------------------------------------------------------------

output "jumpbox_public_ip" {
  description = "Public IP of the jumpbox/bastion"
  value       = module.kubeadm_cluster.jumpbox_public_ip
}

output "jumpbox_private_ip" {
  description = "Private IP of the jumpbox/bastion"
  value       = module.kubeadm_cluster.jumpbox_private_ip
}

output "master_private_ip" {
  description = "Private IP of the master node (no public IP)"
  value       = module.kubeadm_cluster.master_private_ip
}

output "worker_private_ips" {
  description = "Private IPs of all worker nodes (no public IPs)"
  value       = module.kubeadm_cluster.worker_private_ips
}

output "ingress_public_ip" {
  description = "Public VIP for HTTP/HTTPS (Network Load Balancer)"
  value       = module.kubeadm_cluster.ingress_public_ip
}

output "ssh_command_jumpbox" {
  description = "SSH command to connect to the jumpbox"
  value       = module.kubeadm_cluster.ssh_command_jumpbox
}

output "ssh_command_master" {
  description = "SSH command to connect to master via jumpbox"
  value       = module.kubeadm_cluster.ssh_command_master
}

output "kubeadm_join_command" {
  description = "Command to get the join token via jumpbox"
  value       = module.kubeadm_cluster.kubeadm_join_command
}

output "kubectl_tunnel_command" {
  description = "Port-forward API via jumpbox for local kubectl"
  value       = module.kubeadm_cluster.kubectl_tunnel_command
}
