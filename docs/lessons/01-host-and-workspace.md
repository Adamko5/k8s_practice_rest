# Lesson 01: host and workspace

Goal: keep Ubuntu WSL as the operator's personal Linux workstation. Prepare separate guest machines for Kubernetes rather than installing the cluster onto this workstation.

The original operator setup is complete. The kind experiment was also created successfully and has now been retired. The current project direction is four full Linux VMs with manual kubeadm installation. VM backend feasibility and a fresh disk/memory budget remain to be checked.

## Recorded observations

| Item | Observed value |
| --- | --- |
| Operator Linux | Ubuntu 26.04.1 LTS, WSL 2, x86-64 |
| Kernel | 6.18.33.2-microsoft-standard-WSL2 |
| WSL-visible CPU | 32 logical processing units |
| WSL-visible RAM | About 15 GiB total; about 13 GiB available during the replan |
| Git | 2.53.0, Ubuntu package at `/usr/bin/git` |
| Docker | Client/server 29.7.2 through Docker Desktop integration |
| kubectl | 1.36.1, shared as a Linux executable through Docker Desktop |
| SSH | Installed at `/usr/bin/ssh` |
| kind | 0.33.0 remains installed; its old lab cluster was deleted |
| VM tooling | QEMU, virsh, virt-install, and cloud-localds not installed |
| KVM device | `/dev/kvm` exists; the current user cannot open it |

These are observations, not version requirements for every machine. Retain working tools rather than installing duplicate copies. Docker remains useful for future application image builds; Kubernetes nodes will run in VMs.

## Terminal contexts

| Context | What happens there |
| --- | --- |
| Ubuntu WSL workstation | Git, VM lifecycle CLI, SSH, kubectl, image builds, and load generation |
| A named guest VM over SSH | OS preparation, containerd, kubelet, kubeadm, and host troubleshooting |
| A container inside a Pod | Application inspection through kubectl exec or a debug container |

A VM is a full guest OS with its own kernel. A Pod runs containers on a Kubernetes node. A port is a service endpoint on a machine's address; it is not a substitute for a separate machine.

## Locate the checkout and recheck resources

Run from Ubuntu WSL:

```bash
cd /mnt/c/Me/Dev/learning/k8s_commands
pwd
git status --short
cat /etc/os-release
uname -r
uname -m
nproc
free -h
df -h . "$HOME" /mnt/c
```

The checkout remains on the mounted Windows drive. Keep source files here. The VM plan puts large guest disks in a dedicated project storage pool on the Linux filesystem rather than moving this checkout.

WSL filesystem capacity can reflect its virtual disk maximum. Verify actual free space on the physical backing drive before creating sparse guest disks, and budget memory for Ubuntu, guests, Windows, and other work.

## Check the existing operator tools

```bash
command -v git ssh kubectl docker
git --version
ssh -V
kubectl version --client
docker version
kubectl config get-contexts
```

An empty Kubernetes context list is expected after the old lab's removal. Later, we will register the manually installed cluster in the standard `~/.kube/config` under context `bank-lab`. Normal operation will use short kubectl commands and explicit context selection when needed.

Docker Desktop's WSL integration supplies a Linux Docker CLI and engine access. It also currently supplies the Linux kubectl executable. Keep Docker Desktop available for those existing tools; do not install another Docker daemon as VM preparation.

The original hello-world container check passed, as confirmed by the owner. Its image may remain cached. The old kind images and shared Docker network were retained; their presence is not a running cluster.

## Check the local fixture policy

The root `.env` contains the deliberately public local PostgreSQL database name, user, and password. Keep these working fixtures in Git. Nothing currently loads them into an application or cluster.

```bash
git check-ignore --no-index .env
```

No output and exit status 1 means no ignore rule excludes the file. Generated access files and VM seed artifacts are different: they belong in ignored `environment/.state/`. Personal SSH private keys remain with the operator; cloud-init will use a supplied public key for guest login.

The repository's `.gitattributes` preserves Linux LF line endings for source files, including future Bash scripts.

Continue with [Lesson 02: validate the VM backend](02-virtual-machine-feasibility.md).
