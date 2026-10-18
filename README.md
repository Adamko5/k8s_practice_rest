# Kubernetes banking lab

A hands-on project for building and operating a Kubernetes cluster from a Linux terminal.

I'm setting up four Linux virtual machines, installing Kubernetes with kubeadm, and deploying a small REST API backed by fictional banking data. The final experiment starts with one API Pod on one worker. As traffic grows, a Horizontal Pod Autoscaler (HPA) adds replicas on the other workers, then reduces them when traffic drops.

The aim is to understand the setup as well as the application: machine networking, Linux services, containerd, cluster bootstrap, Kubernetes manifests, troubleshooting, and scaling.

## Project status

The personal Ubuntu WSL workstation is prepared. The separate Ubuntu 24.04 distro `k8s-lab` is created and its `lab` login is verified. An initial kind cluster was created and inspected, then removed to include manual host preparation and Kubernetes installation. The [VM setup commands](environment/TODO.md) are ready to run; the VMs and application have not been created yet.

The first checkpoint is to validate the VM backend. QEMU/KVM with libvirt inside WSL is the first candidate. Its device is present, but user access and a working accelerated guest have not been verified.

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
| Node machines | Four Ubuntu Server VMs; QEMU/KVM + libvirt pending feasibility validation |
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
- [Next checkpoint: VM feasibility](docs/lessons/02-virtual-machine-feasibility.md): what to prove before creating four guests.
- [Architecture](ARCHITECTURE.md): the planned components and connections.
- [AI collaboration context](AGENTS.md): scope and guidance for continuing the lab.
