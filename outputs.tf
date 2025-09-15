output "master_public_ip" {
  description = "Public IP address of the K8s master node."
  value       = google_compute_instance.k8s_master.network_interface[0].access_config[0].nat_ip
}

output "worker_1_public_ip" {
  description = "Public IP address of the K8s worker node 1."
  value       = google_compute_instance.k8s_worker_1.network_interface[0].access_config[0].nat_ip
}