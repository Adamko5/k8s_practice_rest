# Context for AI collaborators

## Purpose and learning goal

This repository is a hands-on Kubernetes learning project. The owner started with terminology and some configuration familiarity, but little kubectl experience. They want to learn the full path from separately administered Linux machines to a deployed application and measured autoscaling. They now have some practical experience inspecting a working kind cluster, kubeconfigs, node roles, Pods by node, and DaemonSets.

The owner clarified that the machine layer matters: they want four full Linux VMs that behave like remote hosts, with their own guest kernels, systemd, disks, virtual NICs, IP addresses, SSH access, and independent lifecycle. Mapping four container ports is not equivalent to that requirement. The cluster uses real network connections and distributed Kubernetes components, while all guests still share one physical host and its failure domain.

They want to understand guest preparation, containerd and Kubernetes packages, kubeadm init and join, and Pod networking as separate operations. They initially wanted to run every command themselves, then explicitly asked the agent to execute the containerd stage and explain the result with inspection commands. Follow the current request for who executes a stage. Do not replace these learning steps with a prebuilt Kubernetes node image, kind, minikube, k3s, a turnkey Kubernetes cloud image, or cloud-init that silently installs the cluster. kubeadm is the selected official Kubernetes bootstrap tool; generating every certificate and component manifest by hand is not required by the phrase 'no shortcuts.'

The repository may be public as a portfolio project. Describe implemented behavior and observed results accurately. Do not claim production readiness, physical high availability, benchmark gains, or completed installation steps without evidence.

## Read first and current state

Read `README.md`, `environment/README.md`, `environment/TODO.md`, `TODO.md`, `ARCHITECTURE.md`, and the relevant lesson. Keep environment commands in `environment/TODO.md` and settings beside it.

Use the repository [writer skill](.agents/skills/writer/SKILL.md) when writing docs, lessons, checklists, or explanations. The owner wants short, command-first instructions and will ask for more detail. Keep README brief, put exact commands in TODO, and explain only consequential or unusual operations. Do not add another environment PLAN.md.

On 2026-10-18 the owner requested a planning reset. The original bank-lab kind cluster had four Ready nodes and only system/storage-provisioner Pods. It was deleted explicitly with kind's named-cluster command; its four node containers, the project-generated kubeconfig, its context in the operator's default kubeconfig, and the obsolete kind configuration were removed. No kind clusters remained at the post-delete check. Docker Desktop, shared images/networks, and existing CLI installations were retained. This is completed cleanup, not a VM installation result.

The replacement VM definitions and commands are in `environment/`. The owner installed the VM tools and provisioned all four Ubuntu guests; each finished cloud-init and passed SSH checks. The agent verified control-plane KVM acceleration and TCP/22 connectivity in both directions between the control plane and worker 1. Runtime installation is now complete; Kubernetes installation remains a separate task. Do not recreate the existing guests. `environment/start.sh` and `stop.sh` automate the existing VMs' lifecycle. The owner wants `stop.sh` to terminate only `k8s-lab` by default, after all four VMs are shut off; it never forces a failed shutdown. Optional `--keep-wsl` leaves the lab distro running for terminal work.

The dedicated Ubuntu 24.04 WSL distro `k8s-lab` has default Linux user `lab`. On 2026-10-18 it was moved with WSL's built-in move command to `C:\Me\Dev\WSL\k8s-lab`; its registered path, default login, persistent machine identity, and access to this repo were verified afterward. Creation instructions are step 0 of `environment/TODO.md`; do not reinstall over the existing distro. Personal `Ubuntu` remains the default in its original location. `/dev/kvm` is shared between the observed WSL distros, whose `kvm` group IDs differ (personal Ubuntu 991, lab 993); device ownership has reverted and caused access failures despite correct lab membership. The owner corrected it with `sudo chown root:kvm /dev/kvm` and `sudo chmod 0660 /dev/kvm` inside the lab. Lifecycle scripts report missing KVM access rather than changing shared permissions. Do not start WSL during offline disk compaction.

QEMU/KVM with libvirt inside `k8s-lab` is the selected working backend. The owner installed packages and created the guests manually. The agent has not installed Kubernetes or created additional guests. Keep these guests as the eventual Kubernetes nodes. When reproducing from scratch, validate the first target VM, then two-VM connectivity, before creating the remaining workers. A host-native hypervisor remains the fallback if those checks fail; do not install multiple speculative backends or quietly use software CPU emulation.

The owner reported Lessons 03 and 04 completed on all four guests, including machine inspections, guest swap/modules/sysctls, systemd/cgroup v2, and reboot/persistence checks. On 2026-10-18 the owner explicitly authorized the agent to execute the containerd stage. The agent installed Ubuntu containerd `2.2.1-0ubuntu1~24.04.3`, runc `1.3.4-0ubuntu1~24.04.1`, and crictl `v1.36.0` on all four Ubuntu 24.04 amd64 guests, using the pins and configuration in `environment/runtime/`. Containerd uses config version 3, enabled CRI, OverlayFS, and systemd cgroups; both APT packages are held. Each guest pulled `registry.k8s.io/pause:3.10.1`, rebooted, and passed checks for active/enabled containerd, `RuntimeReady` true, cached image, effective configuration, and no failed units. Raw evidence is ignored under `environment/.state/runtime-install-20261018T185649Z/` and per-guest `.state/` directories. Lesson 05 links to reproduction commands in `environment/TODO.md` steps 19–24 and provides commands to explore the installed runtime. `NetworkReady` is false with `NetworkPluginNotReady`, expected until CNI installation. Kubernetes node packages, bootstrap, CNI installation, and Kubernetes/CNI port checks remain separate following tasks; no Kubernetes has been installed on the guests.

Lesson 05 installs the upstream crictl client at `/usr/local/bin/crictl`. If later Kubernetes packages install a repo-managed cri-tools client, reconcile their versions and remove the lab's superseded manual binary after verifying the package-managed replacement, so it does not shadow updates.

Observed personal workstation: Ubuntu 26.04.1 on WSL 2, x86-64, kernel 6.18.33.2-microsoft-standard-WSL2, 32 logical CPUs, and about 15 GiB WSL-visible RAM. About 13 GiB was available during the replan. Its Git is 2.53.0, Docker client/server 29.7.2, kind 0.33.0, and kubectl 1.36.1. Docker and kubectl there are Linux executables shared through Docker Desktop integration. Do not assume these tools exist in fresh `k8s-lab` or enable Docker Desktop integration as an incidental VM setup step.

## Selected architecture and remaining choices

Use one control-plane VM, `bank-lab-cp1`, and three worker VMs, `bank-lab-worker1` through `bank-lab-worker3`. Initial proposed allocation is 2 vCPUs and 2 GiB RAM each, with 30 GiB disk on the control plane and 25 GiB on each worker. Validate host capacity and real physical disk space before allocating; WSL's virtual disk maximum is not proof of physical free space.

The starting guest image is Ubuntu Server 24.04 LTS, with a dated artifact and checksum to pin during provisioning. Cloud-init can prepare identity, a lab user, authorized public SSH keys, and networking. Leave OS prerequisites, runtime setup, Kubernetes packages, init, CNI, and joins as separate visible operations.

Candidate network: a dedicated private VM subnet with stable address reservations, initially proposed as 192.168.77.0/24. Candidate Pod and Service ranges are 10.244.0.0/16 and 10.96.0.0/12. These are design candidates, not verified allocations; check WSL, Docker, VPN, host, and libvirt routes before adopting them. The operator needs direct VM access, guests need mutual connectivity and outbound package/image access, and the API-server address/name must match certificate SANs.

Kubernetes initially targets a supported 1.36.x patch to reuse the client minor; exact Kubernetes package and CNI versions remain to be selected and pinned before installation. Containerd and runc are already pinned and installed with CRI and systemd cgroups. Flannel is the initial CNI default, installed explicitly at a compatible pinned version. NetworkPolicy enforcement is deferred. kubeadm does not install the CNI or a dynamic storage provisioner; teach those operations explicitly.

The application remains a small REST API backed by one PostgreSQL instance containing fictional banking data. The owner has not chosen the API language or framework. k6, Metrics Server, autoscaling/v2 HPA, and Kustomize after raw manifests remain planned. Docker may build the application image later; deliver images through a registry reachable by the guests, with documented TLS trust, rather than kind load or assumptions about the workstation's image cache.

## The final experiment

1. Start with one API Pod on one worker. All three worker VMs already exist.
2. Generate increasing traffic and observe API CPU demand.
3. Let HPA adjust the API Deployment's replica count from one to three.
4. Keep additional matching API Pods on different workers with required Pod anti-affinity.
5. Reduce traffic and observe scale-down after stabilization.

The restriction is at most one matching API replica per eligible worker. It does not prevent PostgreSQL or system workloads from sharing that guest. This is Pod autoscaling across a fixed VM pool; automatic machine provisioning is deferred.

Preserve these distinctions:

- One Pod runs on one node; it does not span machines.
- One Pod can use multiple cores and much of a guest's capacity if application parallelism and resource configuration permit it. Kubernetes does not impose a universal one-core-per-Pod rule.
- Requests affect scheduling and the denominator for CPU-based HPA targets; limits constrain usage.
- HPA chooses a replica count; workload controllers create Pods, the scheduler assigns nodes, and Services route to ready endpoints.
- Container restarts, Pod replacement, adding replicas, rebooting a guest, and adding machines are different operations.
- VM guests have separate kernels and resource allocations, while still sharing the physical host. Node power/network failure exercises do not prove independent physical failure domains.
- A kubelet service stop does not reliably stop its existing containers. Whole-guest lifecycle belongs to the hypervisor; normal production-style maintenance is one worker at a time with appropriate cordon/drain and recovery checks.

## Versioned local lab configuration and credentials

The owner explicitly wants `.env` and credentials created solely for this disposable local lab to be versioned. Treat them as intentionally public fixtures. The chosen operator login inside `k8s-lab` is username `lab`, password `lab`; this does not change the personal Ubuntu account. Include local database passwords and local Kubernetes Secret definitions in the reproducible project configuration by default. A resource being named `Secret`, or a variable containing `PASSWORD`, is not by itself a reason to exclude it from Git.

Do not add blanket `.env` or local-credential ignore rules, replace working fixture values with placeholders, or insist on a separate untracked secrets workflow. Keep the committed values usable for the documented local setup. An `.env.example` may be useful later, but it must not replace the requested working `.env`.

These values belong only to disposable local services and fictional data. If there is concrete evidence that a value authorizes access to another system, identify the value's purpose and capability and bring that concern to the owner. Examples include a real GitHub/cloud token, a personal SSH private key, or credentials reused by an external database. Explain the actual reason for an exception instead of giving a generic warning based on the file name or the word secret. Do not silently change this policy.

Generated kubeconfigs remain ignored because they contain per-cluster endpoints and access data, change when a cluster is recreated, and are generated by the cluster bootstrap rather than being portable source configuration. This is an explicit generated-file exception, not a ban on committing local application credentials. Backups and raw runtime output remain ignored as generated artifacts.

The root `.env` is the starting source of local database settings. Explain each later command or tool that reads it. Neither `kubectl` nor ordinary Kubernetes YAML automatically loads or substitutes `.env` values.

## Linux workstation, VM, and access workflow

Learning commands and scripts use Linux Bash inside `k8s-lab`; ordinary cluster setup happens over SSH inside the named VMs. Creating/opening the WSL distro is the explicit one-time Windows command exception. Keep VM tooling and large guest disks in `k8s-lab`, preserving personal Ubuntu. Do not install kubelet, containerd, or the control plane directly onto the operator as an incidental lab step. Docker Desktop remains separate; any later use for image builds must account for its storage outside the disposable lab. Do not install a duplicate host Docker daemon.

The existing checkout is `/mnt/c/Me/Dev/learning/k8s_commands` from WSL. Keep source files here and do not move or clone it elsewhere without the owner's request. Treat Ubuntu as a persistent personal computer. Reuse tools, record justified host package/service/group changes, and avoid scattering downloads or logs in the home directory.

Keep planned VM/network definitions, minimal cloud-init inputs, guest configuration examples, exact version records, and commands under `environment/`. Keep generated access and seed artifacts in ignored `environment/.state/`. Large guest disks should live in one documented project storage pool on the Linux filesystem, proposed as `/var/lib/libvirt/images/k8s-banking-lab/`; they should not live in the mounted Windows source checkout. Identify ownership and precise cleanup targets before deleting a guest, pool, or disk.

The owner explicitly selected the standard operator kubeconfig workflow after discussing verbosity: intentionally merge lab-specific entries into `~/.kube/config`, preserve other entries, and use a named context, planned as `bank-lab`. Staging kubeconfigs are generated/ignored. Do not overwrite the personal configuration, silently select another cluster, or edit shell startup files. Normal commands can be short; automation and mutations should target the intended context explicitly. This preference supersedes the earlier project-file-only kubeconfig instructions.

Every command must state its execution context:

- WSL operator: Git, VM lifecycle, SSH, kubectl, image build/push, and load generation.
- Named Linux VM: OS preparation, systemd, containerd, kubelet, kubeadm, guest firewall/network, and logs.
- Pod container: kubectl exec or a debug container for application inspection; use a shell actually available in the image.

SSH is appropriate for the full VM guests. It is unnecessary inside ordinary application containers. Keep durable settings in versioned source configuration instead of leaving unrecorded changes on guests.

Infrastructure definitions may automate creating plain VMs; they must not silently bootstrap Kubernetes. Keep guest/cluster operations visible and explain them. The owner may ask the agent to execute a defined stage, as they did for containerd; this does not authorize subsequent stages. Later convenience scripts must preserve the operation boundaries. Docker Compose is not selected for simulating full node VMs. If the owner explicitly changes that decision, explain the lost guest-kernel boundary and nested-runtime work before redesigning the plan.

Cleanup must target only project-owned resources. Never prune Docker broadly, delete a shared network, remove an entire libvirt pool containing unrelated disks, overwrite existing SSH keys, or stop unrelated workloads. Do not change Windows/WSL-wide settings as incidental troubleshooting. If a selected VM provider requires one-time Windows configuration, explain that specific requirement while keeping routine administration in Linux.

## Application and data scope

Keep the domain small enough that Kubernetes remains the main learning task. Use synthetic customers, accounts, balances, and transaction history. Initial operations include customer create/read/update, account and balance reads, and paginated history reads.

Use deterministic seed data with fictional personal information and example email domains. Represent monetary amounts in integer minor units with an explicit currency; one currency is enough initially. Keep seed balances and history consistent with the documented model.

This is a data-backed API exercise. A complete financial ledger, transfers between accounts, real payments, bank integrations, identity verification, and production authentication are outside the initial scope. Do not use real banking records or payment credentials.

The API also needs:

- A way to identify the instance serving a request.
- Separate startup, readiness, and liveness behavior.
- A bounded CPU-work endpoint that creates real CPU demand for the first HPA experiment.
- Bounded database connection pools and request/dependency timeouts.
- Stateless request handling so any ready replica can serve normal traffic using the shared database.

Choose and document application parallelism alongside each Pod's CPU budget once the language is selected. If the experiment assigns multiple cores to a Pod, configure and verify useful parallel execution for that runtime. Explain application constraints separately from Kubernetes limits, and do not use a timed sleep as evidence of CPU load.

## Kubernetes implementation guidance

### Keep configuration changes readable

Use separate manifest files for distinct resources. Make namespace/labels, Deployment structure, ConfigMaps, Secrets, Services, storage, StatefulSets, Jobs, probes, requests, limits, placement, metrics, and HPA separate learning steps. Several steps may update the same Deployment file; preserve the intermediate changes in Git or lesson notes.

Start with ordinary YAML and explicit `kubectl` commands. Introduce Kustomize only after its input resources make sense. Explain that Kustomize patches/composes manifests and Helm packages templated applications with values. Helm chart authoring is outside the first plan.

VM definitions, network definitions, guest OS/runtime inputs, kubeadm configuration, and pinned add-on sources belong to `environment/`. Keep their commands and lifecycle instructions together there and link from lessons instead of maintaining duplicate runnable definitions. Workload manifests belong to the application layer. Do not use Docker Compose to manage the final Kubernetes workloads or hide all setup in a single script before teaching the individual operations.

### Networking and traffic

Use Services and cluster DNS for application connections. Do not hardcode Pod or node IPs into database connection settings.

The planned API entry point is a worker VM's private IP on NodePort 30080, reached from WSL over the private VM network. The Kubernetes management API uses the control plane's stable private endpoint on 6443. Verify both routes and firewall requirements; no kind/Docker 8080 mapping is carried forward. Keep PostgreSQL internal to the cluster.

`kubectl port-forward` is useful for inspection but selects a Pod for a session, including when invoked against a Service. Use the VM-reachable Service entry point for load tests that are meant to exercise multiple replicas. Connection reuse can keep requests on an endpoint; do not require strict per-request rotation to prove a Service works.

### Persistence, migrations, and recovery

Start with one PostgreSQL Pod in a StatefulSet, a governing headless Service, a normal client Service, and a PVC. Inspect the actual StorageClass and binding behavior. Pin the database to the chosen local-storage worker and explain the scheduling constraint.

Local persistent storage survives the relevant Pod lifecycle operations but is tied to a worker and the cluster's storage arrangement. Do not promise that moving the database Pod to another worker automatically moves its data. Worker-drain exercises must account for this limitation.

Run migrations and seeds as ordered, explicit Jobs with safe retry behavior. Avoid having every API replica race to initialize the database. Bundling resources with Kustomize does not replace waiting for migration completion.

Back up PostgreSQL and test a restore into a separate database. Export backups outside the guest disks, keep them out of Git, and document whether export is manual. A scheduled backup that exists only inside the cluster is not evidence of recovery after cluster deletion. Add CronJob scheduling as its own step.

Increasing a StatefulSet's replica count does not configure PostgreSQL replication. Persistence, replication, backups, failover, and sharding solve different problems. Only single-instance persistence and tested backup/restore belong to the initial database implementation.

### Probes, resources, and placement

Teach startup, readiness, and liveness independently. Readiness may check whether database-backed routes can be served, with bounded timeouts. Liveness should reflect process health; a database outage should not itself trigger repeated API restarts. Reserve capacity and choose probe timings so the load test does not create misleading probe failures.

Budget CPU and memory for the API, database, system components, Metrics Server, and load generator. Use measured values and record requests, limits, and process count. Guest vCPU/RAM allocations define node capacity, while all VMs still share physical host resources. Record both guest allocations and the host budget; do not claim adding guests adds hardware.

Use required API Pod anti-affinity with `kubernetes.io/hostname`, selecting the API's labels in the lab namespace. Restrict the API to eligible workers. With three eligible workers, a fourth matching API Pod is expected to remain Pending. Use that as a temporary scheduling exercise and return the normal configuration to three or fewer replicas.

### Updates and autoscaling

Required anti-affinity affects updates as well as steady-state placement. At three API replicas, all three eligible workers are occupied, so a surge Pod cannot fit. Choose an explicit rollout strategy that makes progress, such as `maxSurge: 0` and `maxUnavailable: 1`, and explain the capacity reduction. That example causes an outage during a one-replica update; document the observed tradeoff instead of claiming zero downtime.

Install a compatible, pinned Metrics Server version and verify the Metrics API before configuring HPA. Configure and verify kubelet serving-certificate trust on the VM cluster; prefer resolving certificate bootstrap/SANs over disabling TLS verification. Any temporary lab exception must be explicit and justified. Do not introduce a Prometheus stack or custom metrics for the first CPU-based experiment.

Use `autoscaling/v2`, a minimum of one replica, and a maximum of three. Teach the CPU target relative to requests, metric collection delays, readiness, scaling policies, and scale-down stabilization. Keep API replica-count ownership with HPA once it is enabled; remove the fixed count from actively applied Deployment configuration and avoid manual scaling during measured runs.

Measure the one-replica baseline before enabling scaling. Record offered traffic, throughput, p95 latency, errors, CPU, ready replicas, and placement. Compare the CPU-work scenario with database-backed traffic. Account for database connections increasing with replicas and worker processes.

## How to collaborate as a tutor

Follow the owner's current request and the relevant step in `TODO.md`. If asked for the next learning step, do not implement the entire remaining plan in one response. If asked to implement a defined scope, carry out that authorized scope without repeatedly requesting permission for routine choices. The owner found blind command copying unhelpful and asked the agent to execute the containerd stage, then summarize what it does and give a few commands to try. Prefer that explanation and inspection pattern when executing a stage for them.

Give the commands and relevant file first. Add a short note for a critical or unusual operation; explain concepts in depth when the owner asks. Keep VM provisioning, guest OS/runtime preparation, Kubernetes bootstrap, cluster administration, application configuration, and application code as separate steps. Avoid repeated goals, focus paragraphs, checklists of hypothetical failures, and recap sections.

Use Linux Bash commands from the WSL operator terminal. Label commands that instead run over SSH inside a named guest or inside a Pod. Inspect the selected hypervisor connection/inventory, Kubernetes context, and Docker build context before relevant changes. Distinguish routine Pod recreation, disk-preserving guest lifecycle, and deleting stored data.

Do not start installations, create clusters, generate application code, or run load tests merely because a documentation change mentions them. Current user instructions determine the authorized work. Do not create cloud resources or start deferred topics as incidental follow-up work.

## Planned repository layout

Create these directories as the corresponding steps need them:

| Path | Purpose |
| --- | --- |
| `environment/` | VM/network definitions, guest bootstrap inputs, manual OS/runtime/kubeadm commands, version pins, lifecycle, and pinned add-ons |
| `app/` | API source, tests, image definition, dependency lock file |
| `db/` | Data dictionary, migrations, deterministic seeds |
| `k8s/base/` | Readable application manifests and later Kustomize entry point |
| `k8s/experiments/` | Small, explained configuration variants when useful |
| `load/` | Repeatable k6 scenarios |
| `docs/lessons/` | Commands, configuration explanations, troubleshooting observations |
| `docs/results/` | Actual measurements, settings, and selected terminal output |
| `backups/` | Local exported backups, ignored by Git |

## Verification and documentation

Keep plan checkboxes honest. Mark a step complete only after its check has been observed. Record any limitation that changes what the result proves.

Use application tests for meaningful application behavior and database integration. Verify Kubernetes behavior by inspecting actual resources, events, logs, traffic, and stored records. Markdown-only edits need link, structure, and diagram checks; they do not require creating a cluster or adding application tests.

Maintain reproducible commands and small notes as work progresses. Record actual tool versions and environment allocation. Never invent benchmark numbers, logs, screenshots, completed checkpoints, or successful restores. Keep README status and architecture consistent with the implementation.

For public-facing writing, use ordinary words, specific facts, and a friendly technical voice. Avoid promotional claims, decorative badges, repeated stock closers, and inflated descriptions of a small lab. A useful editing reference is [Humanizer](https://github.com/blader/humanizer/blob/main/SKILL.md); use its guidance to improve clarity without inventing experiences or changing technical meaning.

## Deferred ideas, including Kafka

Kafka was the other application considered because the owner also wants to learn messaging and autoscaling. The owner selected the REST API and database experiment first.

Do not implement Kafka, brokers, consumers, consumer-lag scaling, KEDA, or another queue as part of this plan. The API/database lab, terminal learning steps, backup/restore, and measured HPA experiment must be complete before that direction is revisited. Completion does not authorize silently starting a second project; follow the owner's next request.

Possible later extensions include PostgreSQL read replicas and failover, database sharding, automatic node provisioning, control-plane HA, cloud deployment, or adding Kafka alongside the API. Keep them out of the initial implementation unless the owner explicitly changes the scope. An ingress controller, enforced NetworkPolicies, and Helm chart authoring can also be separate follow-up exercises.
