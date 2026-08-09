# kubeadm-terraform

Provision a small Kubernetes cluster on GCP with Terraform + kubeadm.

This lab spins up a jumpbox (bastion), a **private** control-plane (master), and **private** worker VMs. It installs CRI-O / kubeadm / kubelet, initializes the cluster, and installs Calico, Metrics Server, and ingress-nginx. Public app traffic enters via an external Network Load Balancer VIP.

## Layout

```text
.
├── module/                     # Reusable Terraform module
│   ├── main.tf                 # VPC, NAT, firewall, jumpbox, LB, master + workers
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars.example
│   └── scripts/
│       ├── install-k8s-deps.sh # OS prep + CRI-O + kube packages
│       ├── master-init.sh      # kubeadm init, Calico, Metrics Server, ingress
│       └── install-ingress.sh  # ingress-nginx + hostNetwork :80/:443
├── examples/
│   └── hello-secure/           # ClusterIP + Ingress + NetworkPolicies sample
└── environment/
    └── staging/                # Example environment that calls the module
```

## What gets created

| Resource | Details |
|---|---|
| VPC + subnet | Custom network, default `10.10.1.0/24` |
| Cloud NAT | Egress for private master/workers (image pulls, packages) |
| Jumpbox | On-demand bastion — **only** admin host with a public IP |
| Master VM | **Private only**; kubeadm init, Calico, Metrics Server, ingress-nginx |
| Worker VMs | **Private only**; deps installed; join manually |
| Ingress NLB | External passthrough LB VIP on `:80`/`:443` → workers |
| Firewall | SSH to jumpbox from `my_ip`; SSH/API VPC-only; HTTP/HTTPS + LB health to workers |

Defaults use **spot/preemptible** `e2-medium` Ubuntu 22.04 for master/workers. The jumpbox is always **on-demand** (`e2-micro` by default).

## Secure access flow

```text
Laptop ──SSH──► jumpbox (public :22, my_ip only)
                  │
                  ├──SSH──► master / workers (private IPs, no public IPs)
                  └──kubectl──► API :6443 (VPC only)

Internet ──:80/:443──► Network Load Balancer VIP
                         └──► private workers (ingress-nginx hostNetwork)
                                └──► ClusterIP Service ──► Pods
```

- Admin path: laptop → jumpbox → private cluster.
- App path: internet → NLB VIP → private workers (not node public IPs).
- Master/workers use Cloud NAT for outbound internet.
- Do **not** expose apps with public NodePort.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.x`
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) authenticated to a project
- An SSH key pair
- A GCP project with Compute Engine enabled

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## Quick start (staging)

```bash
cd environment/staging

# Create local vars (gitignored)
cp ../../module/terraform.tfvars.example terraform.tfvars
# Edit: gcp_project_id, my_ip (YOUR_IP/32), ssh_user, key paths, worker_count, etc.

terraform init
terraform plan
terraform apply
```

Useful outputs after apply:

```bash
terraform output ssh_command_jumpbox
terraform output ssh_command_master
terraform output kubectl_tunnel_command
terraform output ingress_public_ip
terraform output kubeadm_join_command
```

## Access the cluster

```bash
# Jumpbox
eval "$(terraform output -raw ssh_command_jumpbox)"

# Master via ProxyJump
eval "$(terraform output -raw ssh_command_master)"
kubectl get nodes
kubectl get pods -A
```

Optional local kubectl (API tunnel through the jumpbox):

```bash
# Terminal 1
eval "$(terraform output -raw kubectl_tunnel_command)"

# Terminal 2 — copy kubeconfig from master, set server to https://127.0.0.1:6443
scp -o ProxyJump=ubuntu@JUMPBOX_IP ubuntu@MASTER_PRIVATE_IP:~/.kube/config ./kubeconfig
# edit server: https://127.0.0.1:6443
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

`master-init.sh` copies kubeconfig for both `root` and the configured `ssh_user`.

## Join workers

Workers get Kubernetes packages installed, but are **not** auto-joined:

```bash
eval "$(terraform output -raw kubeadm_join_command)"
```

Then SSH to each worker via the jumpbox and run the printed `kubeadm join ...` (with `sudo`):

```bash
ssh -J ubuntu@JUMPBOX_IP ubuntu@WORKER_PRIVATE_IP
```

## Deploy a secured sample app

```bash
# On the master (via ProxyJump)
cd examples/hello-secure   # or scp this folder to the master
chmod +x create-tls-secret.sh
./create-tls-secret.sh
kubectl apply -f hello.yaml

# Hit the NLB VIP (Ingress matches Host: hello.local)
INGRESS_IP=$(terraform -chdir=environment/staging output -raw ingress_public_ip)
curl -H "Host: hello.local" "http://${INGRESS_IP}/"
curl -k -H "Host: hello.local" "https://${INGRESS_IP}/"
```

If ingress-nginx was not installed at cluster create time (existing cluster), run on the master:

```bash
sudo bash /tmp/install-ingress.sh
# or copy module/scripts/install-ingress.sh to the master and run it
```

## Module inputs (common)

| Variable | Default | Notes |
|---|---|---|
| `gcp_project_id` | `core-infra-labs` | Target GCP project |
| `cluster_name` | `k8s` | Prefix for all resources |
| `worker_count` | `1` | Number of worker VMs |
| `instance_type` | `e2-medium` | Master + workers |
| `use_spot_instances` | `true` | Master/workers only; jumpbox is always on-demand |
| `jumpbox_instance_type` | `e2-micro` | Bastion size |
| `my_ip` | `0.0.0.0/0` | Restricts jumpbox SSH; use `YOUR_IP/32` |
| `ssh_user` | `ubuntu` | Must match your SSH key username |
| `ssh_public_key_path` / `ssh_private_key_path` | `~/.ssh/id_rsa(.pub)` | Used by provisioners |

See `module/variables.tf` and `module/terraform.tfvars.example` for the full list.

## Destroy

```bash
cd environment/staging
terraform destroy
```

## Notes / caveats

- Master and workers have **no public IPs**. Only the jumpbox (SSH) and the ingress NLB VIP (HTTP/HTTPS) are public.
- Removing public IPs from an existing cluster **recreates** master/worker VMs (cluster re-init required).
- Prefer setting `my_ip` to your public IP `/32` instead of `0.0.0.0/0`.
- Sample TLS is self-signed (lab). For real certs, add cert-manager + DNS pointing at `ingress_public_ip`.
- Spot VMs can disappear; do not rely on this for durable state. The jumpbox is on-demand on purpose.
- `*.tfvars`, `.terraform/`, and `*.tfstate*` are gitignored — keep secrets and state local (or use a remote backend if you add one).
- Kubernetes / CRI-O versions are pinned in `install-k8s-deps.sh` (currently `1.32`); Calico and ingress-nginx versions are pinned in the install scripts.
