# Kubernetes banking lab

A hands-on project for building and operating a Kubernetes cluster from a Linux terminal.

I'm setting up four Linux virtual machines, installing Kubernetes with kubeadm, and deploying a small REST API backed by fictional banking data. The final experiment starts with one API Pod on one worker. As traffic grows, a Horizontal Pod Autoscaler (HPA) adds replicas on the other workers, then reduces them when traffic drops.

The aim is to understand the setup as well as the application: machine networking, Linux services, containerd, cluster bootstrap, Kubernetes manifests, troubleshooting, and scaling.

## Project status

Four Ubuntu Server VMs now run under QEMU/KVM and libvirt inside the dedicated WSL distro `k8s-lab`. All four finished cloud-init and passed SSH checks. Control-plane KVM acceleration and traffic between the control plane and worker 1 were verified. The earlier kind cluster was removed to practise manual machine preparation and Kubernetes installation.

Guest identity, clock, network, and firewall checks are complete, along with guest OS preparation. Containerd passed reboot checks on all four VMs, and Kubernetes tools `v1.36.5` are installed and pinned. WSL has a matching kubectl client. The [environment guide](environment/TODO.md) covers reproduction and startup/shutdown scripts. Control-plane initialization comes next.

## The machines and the experiment

| Machine | Planned responsibility |
| --- | --- |
| `bank-lab-cp1` | Kubernetes control plane and its local etcd |
| `bank-lab-worker1` | API capacity and the initial PostgreSQL storage location |
| `bank-lab-worker2` | API capacity |
| `bank-lab-worker3` | API capacity |

Each VM has its own Linux kernel, systemd, disk, IP address, and SSH access. The guests communicate as separate hosts, while sharing one physical computer's resources and failure domain. VM creation will prepare plain hosts; the Kubernetes installation stays visible as separate commands.

Three workers exist before autoscaling begins. HPA changes the API's replica count from one to three, and placement rules keep matching API Pods on different workers. Creating new machines automatically is a later topic. PostgreSQL starts as one persistent instance and can share a worker with an API Pod.

## What I'm learning

- Provisioning Linux guests, administering them over SSH, and understanding machine addresses and service ports.
- Preparing the OS, configuring containerd, running kubeadm init/join, and installing Pod networking.
- Using kubectl contexts to inspect resources, read logs, troubleshoot failures, and manage updates.
- Writing manifests for workloads, Services, configuration, credentials, storage, and health probes.
- Running PostgreSQL with migrations, fictional seed data, and a tested backup and restore.
- Measuring resource use, placement, and CPU-based autoscaling with repeatable load tests.

The API will use synthetic customers, accounts, balances, and transaction history. A bounded CPU workload will provide a clear signal for the first HPA experiment. Database-backed traffic can then show when adding API replicas stops helping.

## Planned tools

| Part | Choice |
| --- | --- |
| Operator workstation | Dedicated Ubuntu 24.04 WSL 2 distro `k8s-lab`, Linux Bash and SSH |
| Node machines | Four Ubuntu Server VMs using QEMU/KVM + libvirt |
| Kubernetes installation | Upstream Kubernetes, containerd, manual kubeadm, pinned Flannel CNI |
| Kubernetes operation | kubectl, plain YAML first, Kustomize later |
| REST API | Language and framework to be decided |
| Database | PostgreSQL |
| Load and scaling | k6, Metrics Server, autoscaling/v2 HPA |

The committed `.env` contains intentionally public credentials for the disposable local database. They are part of the reproducible setup and are used only with fictional data.

## Read the project

- [Environment](environment/README.md): machines and addresses.
- [VM setup](environment/TODO.md): commands to create and check the guests.
- [Implementation and learning checklist](TODO.md): separate steps from the workstation to the final HPA experiment.
- [Host and workspace](docs/lessons/01-host-and-workspace.md): completed observations and current workstation checks.
- [Create the Linux machines](docs/lessons/02-virtual-machine-feasibility.md): VM creation and initial checks.
- [Verify the Linux machines](docs/lessons/03-verify-the-linux-machines.md): guest identity, clocks, and networking.
- [Prepare Linux for Kubernetes](docs/lessons/04-prepare-linux-for-kubernetes.md): swap, kernel modules, network sysctls, and a reboot check.
- [Install and inspect containerd](docs/lessons/05-install-containerd.md): runtime packages, CRI, systemd cgroups, and commands to try.
- [Install Kubernetes tools](docs/lessons/06-install-kubernetes-tools.md): kubeadm, kubelet, kubectl, and the state before bootstrap.
- [Architecture](ARCHITECTURE.md): the planned components and connections.
- [AI collaboration context](AGENTS.md): scope and guidance for continuing the lab.
