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

Follow [TODO.md](TODO.md). The WSL distro is ready; VM creation commands have not been run yet. This creates plain Linux machines; containerd and Kubernetes come afterward. WSL/KVM support must pass the first-VM checks before continuing.
