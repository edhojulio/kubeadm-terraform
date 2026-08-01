# kubeadm-terraform

Provision a small Kubernetes cluster on GCP with Terraform + kubeadm.

This lab spins up a control-plane (master) and optional worker VMs, installs CRI-O / kubeadm / kubelet, initializes the cluster, and installs Calico plus Metrics Server.

## Layout

```text
.
├── module/                     # Reusable Terraform module
│   ├── main.tf                 # VPC, firewall, master + workers
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tfvars.example
│   └── scripts/
│       ├── install-k8s-deps.sh # OS prep + CRI-O + kube packages
│       └── master-init.sh      # kubeadm init, Calico, Metrics Server
└── environment/
    └── staging/                # Example environment that calls the module
```

## What gets created

| Resource | Details |
|---|---|
| VPC + subnet | Custom network, default `10.10.1.0/24` |
| Static IP | Reserved public IP for the master |
| Master VM | kubeadm init, Calico CNI, Metrics Server |
| Worker VMs | deps installed; join manually |
| Firewall | SSH (from `my_ip`), internal all, API `6443`, NodePort `30000-32767` |

Defaults use **spot/preemptible** `e2-medium` Ubuntu 22.04 nodes (cheap for labs; can be reclaimed by GCP).

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
# Edit: gcp_project_id, my_ip, ssh_user, key paths, worker_count, etc.

terraform init
terraform plan
terraform apply
```

Useful outputs after apply:

```bash
terraform output ssh_command_master
terraform output master_public_ip
terraform output kubeadm_join_command
```

## Join workers

Workers get Kubernetes packages installed, but are **not** auto-joined. On the master:

```bash
# From your laptop (uses Terraform output helper)
eval "$(terraform output -raw kubeadm_join_command)"

# Or SSH in and print it yourself
sudo kubeadm token create --print-join-command
```

Then run the printed `kubeadm join ...` command on each worker (with `sudo`).

## Access the cluster

```bash
ssh USER@MASTER_PUBLIC_IP
kubectl get nodes
kubectl get pods -A
```

`master-init.sh` copies kubeconfig for both `root` and the configured `ssh_user`.

The master's public IP is added as an API server cert SAN so `kubectl` / API access via the static IP works.

## Module inputs (common)

| Variable | Default | Notes |
|---|---|---|
| `gcp_project_id` | `core-infra-labs` | Target GCP project |
| `cluster_name` | `k8s` | Prefix for all resources |
| `worker_count` | `1` | Number of worker VMs |
| `instance_type` | `e2-medium` | Master + workers |
| `use_spot_instances` | `true` | Cheaper; may be preempted |
| `my_ip` | `0.0.0.0/0` | Restrict SSH to `YOUR_IP/32` |
| `ssh_user` | `ubuntu` | Must match your SSH key username |
| `ssh_public_key_path` / `ssh_private_key_path` | `~/.ssh/id_rsa(.pub)` | Used by provisioners |

See `module/variables.tf` and `module/terraform.tfvars.example` for the full list.

## Destroy

```bash
cd environment/staging
terraform destroy
```

## Notes / caveats

- Lab-oriented: API (`6443`) and NodePort ranges are open to the internet. Tighten firewalls before anything non-lab.
- Prefer setting `my_ip` to your public IP `/32` instead of `0.0.0.0/0`.
- Spot VMs can disappear; do not rely on this for durable state.
- `*.tfvars`, `.terraform/`, and `*.tfstate*` are gitignored — keep secrets and state local (or use a remote backend if you add one).
- Kubernetes / CRI-O versions are pinned in `install-k8s-deps.sh` (currently `1.32`); Calico version is pinned in `master-init.sh`.
