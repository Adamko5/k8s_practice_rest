# Environment

Four Ubuntu 24.04 VMs, managed from a dedicated Ubuntu 24.04 WSL distro named `k8s-lab`, using QEMU/KVM, libvirt, and SSH.

| VM | IP | vCPUs | RAM | Disk capacity |
| --- | --- | ---: | ---: | ---: |
| `bank-lab-cp1` | `192.168.77.10` | 2 | 2 GiB | 30 GiB |
| `bank-lab-worker1` | `192.168.77.11` | 2 | 2 GiB | 25 GiB |
| `bank-lab-worker2` | `192.168.77.12` | 2 | 2 GiB | 25 GiB |
| `bank-lab-worker3` | `192.168.77.13` | 2 | 2 GiB | 25 GiB |

Each VM has its own kernel, disk, IP, and SSH server. They share the physical PC. The private network allows outbound internet access through NAT.

The WSL disk lives in `C:\Me\Dev\WSL\k8s-lab`. VM disks live inside it at `/var/lib/libvirt/images/k8s-banking-lab/`. Sparse VM disks grow as used; 105 GiB is their combined capacity. The repo stays on Windows; generated files go in ignored `.state/`.

All four VMs have containerd and pinned Kubernetes tools `v1.36.5`. The control plane is initialized and its API is ready. Context `bank-lab` works from WSL and as `lab` inside cp1, using each user's `~/.kube/config`. The workers have not joined; Flannel installation is next. See [kubeconfig setup](TODO.md#36-configure-the-wsl-operator-context) for reproduction.

Follow [TODO.md](TODO.md) to reproduce the setup. Use [start.sh](start.sh) and [stop.sh](stop.sh) for daily startup and shutdown; commands are in [Daily commands](TODO.md#daily-commands).
