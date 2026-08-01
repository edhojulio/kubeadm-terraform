#!/bin/bash
# -----------------------------------------------------------------------------
# master-init.sh
#
# A fully automated script to initialize a Kubernetes control-plane node AND
# install Calico CNI.
#
# Usage: sudo ./master-init.sh <ssh_user> [public_ip]
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# Run install k8s dependency script.
/bin/bash /tmp/install-k8s-deps.sh

# --- Configuration ---
CALICO_VERSION="v3.29.1"
NON_ROOT_USER="${1:-}"
PUBLIC_IP="${2:-}"

if [ -z "$NON_ROOT_USER" ]; then
    echo "Warning: No SSH user provided. kubectl will only be configured for root."
fi

# --- Step 1: Detect Primary IP Address ---
echo "--- Step 1: Detecting primary IP address ---"
local_ip=$(hostname -I | awk '{print $1}')

if [ -z "$local_ip" ]; then
    echo "Error: Could not determine the node's IP addresses. Exiting"
    exit 1
fi

echo "Found IP: $local_ip"

# --- Step 2: Create a Kubeadm Configuration ---
echo "--- Step 2: Creating minimal kubeadm configuration file ---"
sudo mkdir -p /etc/kubernetes

CERT_SANS_BLOCK=""
if [ -n "$PUBLIC_IP" ]; then
    CERT_SANS_BLOCK=$(cat <<SANS
apiServer:
  certSANs:
    - "$PUBLIC_IP"
    - "$local_ip"
SANS
    )
fi

cat <<EOF | sudo tee /etc/kubernetes/kubeadm.config
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$local_ip"
nodeRegistration:
  kubeletExtraArgs:
    node-ip: "$local_ip"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
${CERT_SANS_BLOCK}
networking:
  podSubnet: "10.244.0.0/16"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: "systemd"
EOF

# --- Step 3: Initialize the Kubernetes Cluster ---
echo "--- Step 3: Initializing Kubernetes cluster with kubeadm ---"
sudo kubeadm init --config=/etc/kubernetes/kubeadm.config

# --- Step 4: Configure kubectl for root (needed for subsequent commands) ---
echo "--- Step 4: Configuring kubectl for root user ---"
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

# --- Step 5: Configure kubectl for the non-root user ---
if [ -n "$NON_ROOT_USER" ] && id "$NON_ROOT_USER" &>/dev/null; then
    echo "--- Step 5: Configuring kubectl for user '$NON_ROOT_USER' ---"
    USER_HOME=$(getent passwd "$NON_ROOT_USER" | cut -d: -f6)
    mkdir -p "$USER_HOME/.kube"
    cp /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
    chown -R $(id -u "$NON_ROOT_USER"):$(id -g "$NON_ROOT_USER") "$USER_HOME/.kube"
fi

# --- Step 6: Install Metric Server ---
echo "--- Step 6: Installing Metrics Server ---"
kubectl apply -f https://raw.githubusercontent.com/techiescamp/cka-certification-guide/refs/heads/main/lab-setup/manifests/metrics-server/metrics-server.yaml

# --- Step 7: Install the Tigera Calico Operator ---
echo "--- Step 7: Installing the Tigera Calico Operator ---"
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

# --- Step 8: Wait for the Operator to be ready ---
echo "--- Step 8: Waiting for the Tigera Operator to be available ---"
kubectl wait --namespace tigera-operator --for=condition=available deployment/tigera-operator --timeout=120s

# --- Step 9: Discover the Pod CIDR ---
echo "--- Step 9: Discovering the cluster's Pod CIDR ---"
pod_cidr=$(kubectl -n kube-system get pod -l component=kube-controller-manager -o yaml | awk -F'=' '/cluster-cidr/ {print $2}')

if [ -z "$pod_cidr" ]; then
    echo "Error: Could not automatically discover the pod CIDR. Aborting."
    exit 1
fi
echo "Found Pod CIDR: $pod_cidr"

cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configure Calico networking.
  calicoNetwork:
    # Use the discovered pod CIDR.
    ipPools:
    - blockSize: 26
      cidr: $pod_cidr
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF

# --- Step 10: Final Verification and Success Message ---
echo ""
echo "✅✅✅ Master Node Initialization and Calico CNI installation complete! ✅✅✅"
echo ""
echo "It may take a few minutes for all the system pods to become ready."
echo "Monitor the progress with the following command:"
echo "  watch kubectl get pods --all-namespaces"
echo ""
echo "Your cluster join command for worker nodes was printed by 'kubeadm init' earlier."
echo "If you need to see it again, run: sudo kubeadm token create --print-join-command"
echo ""