#!/bin/bash
# -----------------------------------------------------------------------------
# install-k8s-deps.sh
#
# A consolidated script to prepare a Debian-based system and install all
# dependencies for a Kubernetes node:
# 1. Configures system settings (disables swap, loads kernel modules).
# 2. Adds repositories for CRI-O and Kubernetes.
# 3. Installs all packages (CRI-O, Kubelet, Kubeadm, etc.) in one go.
# 4. Enables the CRI-O container runtime.
# 5. Holds Kubernetes package versions to prevent accidental upgrades.
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
CRIO_VERSION="1.32"
K8S_VERSION="1.32"

# --- 1. Configure System Prerequisites ---
echo "--- Step 1: Configuring system prerequisites ---"
echo "Disabling swap..."
sudo swapoff -a
# Make swap disable persistent
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Enabling required kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "Configuring sysctl parameters for Kubernetes networking..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# --- 2. Add Container Runtime & Kubernetes Repositories ---
echo "--- Step 2: Adding APT repositories for CRI-O and Kubernetes ---"
# Install prerequisite packages for adding repositories
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gpg apt-transport-https

# Ensure the keyrings directory exists
sudo mkdir -p /etc/apt/keyrings

# Add CRI-O repository
curl -fsSL "https://pkgs.k8s.io/addons:/cri-o:/stable:/v${CRIO_VERSION}/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/v${CRIO_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list > /dev/null

# Add Kubernetes repository
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

# --- 3. Install All Packages ---
echo "--- Step 3: Updating package list and installing all components ---"
# Update package list again to include new repositories
sudo apt-get update -y

# Install all required packages in a single command
sudo apt-get install -y \
  cri-o \
  kubelet \
  kubeadm \
  kubectl \
  jq

# --- 4. Enable Container Runtime ---
echo "--- Step 4: Enabling the CRI-O container runtime ---"
sudo systemctl daemon-reload
sudo systemctl enable --now crio

# --- 5. Finalize Kubernetes Setup ---
echo "--- Step 5: Holding Kubernetes packages ---"
sudo apt-mark hold kubelet kubeadm kubectl

echo ""
echo "✅✅✅ All Kubernetes dependencies have been installed and configured successfully! ✅✅✅"
echo "The node is now ready. You can use 'kubeadm init' or 'kubeadm join'."
echo "To check CRI-O status, run: sudo systemctl status crio"