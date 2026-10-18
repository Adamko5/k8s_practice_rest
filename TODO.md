# Implementation and learning plan

Build a local distributed Kubernetes lab across **four full Linux VMs**: one control plane and three workers. Prepare the guests and install upstream Kubernetes manually with kubeadm. Then deploy a REST API and PostgreSQL, and finish with CPU-based HPA scaling one to three API replicas onto different workers.

The owner wants the experience of administering separate remote Linux machines. A port mapping is not a machine boundary. Each guest must have its own kernel, systemd, persistent disk, virtual NIC, address, and SSH access. All guests still share one physical host and its failure domain.

## Current checkpoint

- [x] The Ubuntu WSL operator workstation and Git workspace were prepared and checked.
- [x] The initial kind cluster ran successfully; the owner inspected four Ready nodes and system Pods.
- [x] On 2026-10-18, the owner requested a reset. The named kind cluster, its four node containers, its project kubeconfig, and its default kubeconfig context were removed. The obsolete kind configuration was retired.
- [x] Create the dedicated Ubuntu 24.04 WSL distro `k8s-lab`, verify its `lab` login, and move its storage to `C:\Me\Dev\WSL\k8s-lab`. VM tools and guest disks will live there, separate from personal Ubuntu.
- [ ] Validate and implement the replacement VM environment. No VM backend or guest has been installed for this new plan.

Follow [environment/TODO.md](environment/TODO.md) for VM setup commands. QEMU/KVM with libvirt inside WSL still needs to pass its first-VM checks. The VM tools are not installed yet.

The API language and framework remain the owner's choice. PostgreSQL, fictional banking data, k6, and the final HPA experiment stay in scope. Kafka and database replication/sharding remain deferred.

## How to use this plan

Work through one numbered step at a time. Keep machine provisioning, Linux host preparation, Kubernetes bootstrap, cluster administration, application configuration, and application code separate. Run the first installation manually, inspect it, and only then capture reusable automation that preserves the visible lesson boundaries.

Keep executable environment definitions and their commands in `environment/`. Lessons explain why each group exists and link to that command reference. Every command must identify its execution context: WSL workstation, a named VM over SSH, or a container inside a Pod. Mark a check complete only after observing its result. Paths below are planned outputs until their files have been created and validated.

## Part 1: operator workstation and separate Linux machines

### 01. Preserve and recheck the operator workstation

Focus: personal Ubuntu workstation, Git, and resources. See [Lesson 01](docs/lessons/01-host-and-workspace.md).

- [x] Prepare Ubuntu on WSL 2 and verify Linux Git, kubectl, SSH, and the existing Docker build workflow.
- [x] Establish Linux Bash commands and a clean project workspace; keep local `.env` fixtures versioned and generated artifacts ignored.
- [x] Record the observed WSL resources and existing tool versions. Retain the useful setup work from the first experiment.
- [ ] Recheck the host memory and actual physical disk budget before allocating VM disks and RAM. Do not equate WSL virtual disk capacity with physical free space.

Check: WSL remains the operator machine, not a Kubernetes node. Existing personal tools and unrelated resources are preserved.

### 02. Validate the VM backend on one guest

Focus: hardware virtualization and host capabilities. Follow [Lesson 02](docs/lessons/02-virtual-machine-feasibility.md).

- [ ] Review KVM availability, access permissions, systemd, nested virtualization, Linux host support, and existing VM tooling without making speculative changes.
- [ ] Implement the chosen backend prerequisites deliberately; first candidate is QEMU/KVM + libvirt using `qemu:///system` inside WSL. Record the packages, groups, services, and storage locations introduced.
- [ ] Boot `bank-lab-cp1` with hardware acceleration. Verify SSH from WSL, outbound connectivity, disk persistence, and shutdown/start. Add `bank-lab-worker1` and verify two-guest connectivity before creating the remaining workers.
- [ ] Keep successful guests as the final nodes. If the backend fails, select and document a host-native VM provider before proceeding; retain Linux/SSH operations inside the lab.

Check: the selected backend has an observed accelerated guest and working private networking. Do not proceed with unverified KVM or silently substitute container nodes or software CPU emulation.

### 03. Define the machine inventory, image, disks, and private network

Focus: reproducible infrastructure definitions. Files: `environment/inventory.tsv`, `environment/config.env`, `environment/network.xml`, `environment/vm.xml.template`, and `environment/user-data.yaml.template`.

- [ ] Define `bank-lab-cp1` and `bank-lab-worker1` through `bank-lab-worker3`. Start with 2 vCPUs and 2 GiB RAM per guest, with the proposed 30/25 GiB disks, then validate the budget.
- [ ] Select and pin a dated Ubuntu Server 24.04 LTS cloud image and checksum. Record the chosen VM tooling and storage pool.
- [ ] Define a dedicated private network, stable address reservations, and outbound access. Check route conflicts before adopting the proposed VM, Pod, and Service CIDRs.
- [ ] Keep cloud-init limited to guest identity, login, authorized public SSH keys, and initial networking. It must not install Kubernetes or execute kubeadm.
- [ ] Keep large disks in one named Linux-filesystem pool and generated seed/access files in ignored `environment/.state/`. Document ownership and scoped cleanup.

Check: the learner can read what machines will exist, their addresses and resources, and what plain VM creation does before running it.

### 04. Create four plain Linux VMs

Focus: separate guest operating systems before Kubernetes.

- [ ] Create the four VMs from the reviewed definitions and verify their resource assignments, virtual NICs, guest kernels, and persistent disks.
- [ ] SSH into each VM and identify its hostname and operating system. Record how to use the hypervisor console if SSH fails.
- [ ] Prove that the guests contain no preinstalled Kubernetes cluster. Keep the successful clean-guest definitions as a reproduction checkpoint.

Check: four full Linux guests exist and can be administered independently; no `kubeadm init` or worker joins have happened implicitly.

### 05. Verify node networking and service ports

Focus: machines have addresses; services listen on ports.

- [ ] Verify WSL-to-guest SSH and guest-to-guest communication in both directions. Confirm outbound DNS and package/image access.
- [ ] Establish stable control-plane IP/name resolution and document the intended API endpoint on port 6443.
- [ ] Review guest firewall rules and Kubernetes/CNI port requirements without disabling firewalls as a blanket fix.
- [ ] Separate VM addresses, the planned Pod network, the Service network, and the later NodePort 30080. Record routes and MTU assumptions.

Check: required host connections work, address ranges do not overlap, and there is no dependency on Docker port mappings.

### 06. Verify guest identity, time, and basic administration

Focus: each VM behaves as its own host.

- [ ] Verify unique hostnames, MAC addresses, machine IDs, and virtual hardware UUIDs.
- [ ] Verify time synchronization and working name resolution on every guest.
- [ ] Inspect systemd services, network interfaces, memory, CPU, and disk space from each guest. Keep the operator's system configuration separate.

Check: the four hosts can be distinguished and diagnosed before Kubernetes installation.

## Part 2: manual Kubernetes installation

### 07. Prepare the Linux guests for Kubernetes

Focus: OS prerequisites. Planned documented inputs: `environment/nodes/`.

- [ ] Choose and apply the guest swap policy explicitly; start with swap disabled for the first kubeadm build.
- [ ] Apply the kernel modules, forwarding, bridge/network sysctls, and other prerequisites required by the selected runtime and CNI versions.
- [ ] Explain transient versus persistent settings and verify them after a guest reboot.
- [ ] Record every change and its purpose. Run these commands inside the guests, not on the WSL workstation.

Check: all four guests satisfy the selected Kubernetes installation prerequisites after reboot.

### 08. Install and configure containerd

Focus: the Container Runtime Interface (CRI) and cgroups.

- [ ] Select and pin a containerd release compatible with the chosen Kubernetes version and guest OS.
- [ ] Install it manually on each VM, enable CRI, and configure systemd cgroups using the correct configuration format for that containerd version.
- [ ] Inspect the service, socket, logs, and runtime information before installing the control plane. Explain Docker image building versus containerd running Pods.

Check: the runtime is healthy on every VM and its configuration is understood independently of Kubernetes.

### 09. Install Kubernetes node tools and pin versions

Focus: packages and component responsibilities.

- [ ] Select an actively supported patch release, initially targeting Kubernetes 1.36.x to match the existing client minor, and verify the guest/runtime/CNI compatibility matrix.
- [ ] Configure the official package repository and install exact kubeadm and kubelet versions on each guest. Install kubectl where needed and retain a compatible workstation client.
- [ ] Record repository keys, package versions, holds, and intentional update procedures. Explain kubeadm, kubelet, and kubectl separately.
- [ ] Inspect the kubelet unit and recognize that bootstrap may be incomplete before init/join; do not mistake that expected stage for a completed cluster.

Check: exact packages are installed, a version record exists, and Kubernetes has not yet been initialized.

### 10. Initialize the control plane with kubeadm

Focus: bootstrap and cluster configuration. Planned file: `environment/kubernetes/kubeadm-init.yaml`.

- [ ] Write and review the versioned kubeadm configuration: supported config API, node identity, stable API endpoint, certificate SANs, runtime socket, Pod CIDR, and Service CIDR.
- [ ] Run `kubeadm init` manually on `bank-lab-cp1` and inspect its output, certificates, kubelet configuration, static Pod manifests, and local etcd data.
- [ ] Explain why a single control plane and no installed Pod network are expected at this stage. Inspect the resulting system components without changing their generated files casually.

Check: the control-plane API is reachable using its generated access configuration. Pending or NotReady networking-dependent components are explained before CNI installation.

### 11. Install the Pod network

Focus: the Container Network Interface (CNI). Planned pinned source and settings: `environment/kubernetes/`.

- [ ] Review and install a compatible, pinned Flannel release explicitly. Match its Pod network to the kubeadm configuration.
- [ ] Inspect its DaemonSet, node networking, routes, and logs. Explain the difference between machine networking, Pod networking, and Service networking.
- [ ] Inspect CoreDNS readiness as the network becomes available. Keep NetworkPolicy enforcement deferred; Flannel alone is not evidence of policy enforcement.

Check: the CNI is healthy on the control plane; cross-worker connectivity is verified after workers join.

### 12. Join the three workers manually

Focus: discovery, bootstrap credentials, and node registration.

- [ ] Review the kubeadm join command, its control-plane endpoint, token, and discovery verification.
- [ ] Join each worker over SSH with an explicit command. Explain how to generate a replacement join command if its bootstrap token expires.
- [ ] Verify four Ready nodes and CNI Pods on the eligible nodes.
- [ ] Use temporary diagnostic workloads to prove cross-node Pod connectivity and cluster DNS, then remove them.

Check: this is a working upstream Kubernetes cluster distributed across four Linux VMs, with an observed installation path.

## Part 3: operator access and cluster basics

### 13. Configure kubeconfig and contexts for normal operation

Focus: how the operator authenticates and selects a cluster.

- [ ] Stage generated access configuration in ignored `environment/.state/`, with lab-specific cluster/user/context names.
- [ ] Deliberately merge lab access into the owner's standard `~/.kube/config` while preserving other entries. Use context `bank-lab`; do not overwrite the personal file or require shell startup edits.
- [ ] Practice `kubectl config get-contexts`, `current-context`, `use-context`, and explicit `--context`. Explain that a context combines cluster, user, and an optional namespace.
- [ ] Verify ordinary `kubectl get nodes` works in a fresh terminal. Explain that local bootstrap-admin access is different from a company's identity and RBAC setup.

Check: the learner knows which cluster commands affect and can use the normal kubectl workflow without repeating a project file flag.

### 14. Practice machine lifecycle and cluster recovery

Focus: machine power versus Kubernetes resource management.

- [ ] Document provider-specific graceful shutdown, start, reboot, console, and disk-preserving lifecycle commands for each guest.
- [ ] Reboot a worker and observe its node status and system Pod recovery.
- [ ] Shut down the whole lab deliberately, then start the control plane followed by workers and verify recovery. Record that single-control-plane management is unavailable while that guest is down.
- [ ] Distinguish stopping guests from deleting guest disks, resetting kubeadm, and deleting Kubernetes data. Stopping kubelet alone is not a complete node shutdown.

Check: the cluster resumes from persistent guest disks, and the learner can operate the machines without using Docker node-container commands.

### 15. Inspect the cluster and its system workloads

Focus: explain what is running and why.

- [ ] Practice `cluster-info`, `get nodes -o wide`, `describe node`, `api-resources`, and `explain`.
- [ ] Inspect control-plane static Pods, CoreDNS, CNI Pods, kube-proxy, and DaemonSets; group Pods by node.
- [ ] Inspect capacity, allocatable resources, taints, namespaces, and controller ownership. Explain why role labels do not install components.
- [ ] Inspect guest kubelet/containerd services and logs over SSH. Keep application-container inspection separate from host administration.

Check: the learner can trace WSL kubectl -> Kubernetes API -> controllers/scheduler -> guest kubelet/containerd -> application containers.

### 16. Create a namespace and learn labels and selectors

Focus: grouping resources and matching them. Planned file: `k8s/base/namespace.yaml`.

- [ ] Create the `bank-lab` namespace and practice explicit namespace flags.
- [ ] Choose consistent application labels for the API and database. Explain how selectors match labels.
- [ ] Label the three workers as eligible for the API and choose one worker for local PostgreSQL storage.
- [ ] Practice filtering resources by namespace and label, including inspecting resources across all namespaces.

Check: the namespace exists and worker labels identify the intended placement without hardcoding application connections to node IPs.

## Part 4: the application and its image

### 17. Define fictional banking data

Focus: a small data model for the lab. Planned location: `db/`.

- [ ] Define synthetic customers, accounts, account balances, and transaction history with clear relationships.
- [ ] Use integer minor units for money, an explicit currency, and consistent seed balances and history. Keep the initial dataset to one currency.
- [ ] Specify deterministic seed records and pagination so tests and load runs can use repeatable inputs.
- [ ] Keep personal information fictional, use example email domains, and omit real payment credentials or bank integrations.

Check: a short data dictionary explains the records and relationships. Transfers, a complete financial ledger, and payment processing are outside the initial API.

### 18. Implement the REST API locally

Focus: application behavior. Planned location: `app/`.

- [ ] Choose the API language and framework with the owner, then set up and document the application tooling.
- [ ] Implement customer create/read/update operations, account and balance reads, and paginated transaction-history reads.
- [ ] Add separate startup, readiness, and liveness endpoints, plus a response header or endpoint identifying the serving Pod.
- [ ] Add a bounded CPU-work endpoint for the scaling experiment. Put limits on the work per request; sleeping is not a CPU workload.
- [ ] Add meaningful tests for validation, stored data, and error responses. Plan database integration checks for when PostgreSQL is available.
- [ ] Keep the process able to start for health and identity inspection before database wiring; database-dependent endpoints should report unavailability honestly.

Check: the process starts locally, basic endpoints work, and CPU work is measurable. Banking operations will be verified against PostgreSQL in step 27.

### 19. Build and deliver the container image

Focus: the artifact Kubernetes runs. Planned outputs: `app/Dockerfile`, dependency lock file, and `.dockerignore`.

- [ ] Build a versioned API image with an explicit command, a small runtime, and a non-root application user.
- [ ] Run and inspect it directly with Docker, including logs, port mapping, and process shutdown.
- [ ] Set up a lab OCI registry reachable by all VMs, document its endpoint and TLS trust, and push the versioned image. Verify containerd on every worker can pull it; explain image tags, digest pins, and pull policy.

Check: the container serves the same basic endpoints as the local process, and every worker can use the chosen image tag.

## Part 5: workloads, configuration, networking, and state

### 20. Create the API Deployment

Focus: desired state, Pods, and ReplicaSets. Planned file: `k8s/base/api-deployment.yaml`.

- [ ] Create a Deployment with one API replica and the local image.
- [ ] Explain `apiVersion`, `kind`, metadata, selector, Pod template, container image, and container port. Distinguish declaring a port from exposing it.
- [ ] Inspect the Deployment, ReplicaSet, and Pod ownership chain. Delete the API Pod and watch its replacement.

Check: one API Pod runs and is recreated by its controller. Database-dependent routes remain unavailable until step 27.

### 21. Add non-secret configuration with a ConfigMap

Focus: application settings. Planned file: `k8s/base/api-configmap.yaml`.

- [ ] Move settings such as database host, database name, log level, and bounded-work configuration into a ConfigMap.
- [ ] Wire the settings into the Deployment and explain environment-variable versus mounted-file configuration.
- [ ] Change one setting and observe when it reaches the running application, including the restart needed for environment variables.

Check: a configuration change can be applied and verified without rebuilding the image.

### 22. Add credentials with a Secret

Focus: Kubernetes Secret resources using intentionally public lab credentials. Planned output: reproducible Secret creation from versioned local values.

- [ ] Use the committed `.env` values to create the local database Secret and reference it from the relevant workloads. Explain the explicit command that reads `.env`.
- [ ] Keep disposable local credentials and their configuration versioned. Explain that a Kubernetes Secret is a resource type and base64 encoding is not encryption.
- [ ] Practice inspecting metadata, references, and the local fixture values. If a value actually grants access outside this disposable lab, explain that concrete exception to the owner.

Check: workloads can reference the Secret, and a fresh checkout contains the working local fixture values needed to recreate it.

### 23. Add Services and test cluster DNS

Focus: stable addresses and traffic routing. Planned files: `k8s/base/api-service.yaml` and `k8s/base/postgres-service.yaml`.

- [ ] Create a ClusterIP Service for the API and another for PostgreSQL.
- [ ] Explain `selector`, `port`, `targetPort`, and Service DNS names. Inspect EndpointSlices.
- [ ] Use a temporary diagnostic Pod to resolve DNS and reach the API through its Service.
- [ ] Break and fix a selector to observe the difference between a running Pod and a Service with usable endpoints.

Check: the API is reachable inside the cluster by Service name. The PostgreSQL Service will gain an endpoint after step 25.

### 24. Add persistent storage

Focus: StorageClass, PersistentVolume, and PersistentVolumeClaim. Planned file: `k8s/base/postgres-pvc.yaml`.

- [ ] Inspect StorageClasses on the kubeadm cluster, where a dynamic provisioner is not installed automatically. Review and install a compatible, pinned local-storage provisioner as its own explicit operation.
- [ ] Create a database PVC and explain provisioning, access mode, binding mode, capacity, and reclaim policy.
- [ ] Inspect how the chosen provisioner stores data on a worker. Explain why a claim may wait for its consuming Pod before binding.
- [ ] Document the difference between Pod deletion, PVC deletion, node loss, and cluster deletion for this storage setup.

Check: the storage path and data-loss boundaries are understood. If binding waits for a consumer, verify that it binds in step 25.

### 25. Deploy PostgreSQL with a StatefulSet

Focus: a stateful workload. Planned files: `k8s/base/postgres-statefulset.yaml` and `k8s/base/postgres-headless-service.yaml`.

- [ ] Create one PostgreSQL instance, mount its PVC, reference its credentials, and select the worker chosen for storage.
- [ ] Add its governing headless Service and explain how that differs from the normal database client Service.
- [ ] Explain stable Pod identity and compare the StatefulSet with the API Deployment. Keep the database replica count at one.
- [ ] Write a test record, recreate the database Pod, and verify the record survives.

Check: PostgreSQL is reachable through the client Service and retains data across Pod recreation. No database replication or automatic storage failover is claimed.

### 26. Run migrations and seed data with Jobs

Focus: tasks that complete. Planned files: `k8s/base/db-migrate-job.yaml` and `k8s/base/db-seed-job.yaml`.

- [ ] Implement versioned database migrations and a repeatable seed operation.
- [ ] Run migrations and seeds as separate Jobs with explicit ordering, completion checks, and logs.
- [ ] Explain Job retry behavior and why migration code must handle retries safely. Avoid running migrations independently in every API replica.

Check: schema and synthetic data exist. Repeating the seed operation behaves as documented without duplicating records unexpectedly.

### 27. Connect the API to PostgreSQL

Focus: the complete request path and shared application state.

- [ ] Wire database settings and credentials into the API, using the database Service name.
- [ ] Set bounded connection pools and timeouts. Account for the product of API replicas, worker processes, and connections per process.
- [ ] Exercise customer writes, account reads, pagination, and missing-record errors against the real database.
- [ ] Verify stored data survives API Pod replacement. Keep shared business state in PostgreSQL.

Check: requests travel from the API to PostgreSQL and return the expected synthetic records. Integration checks pass.

### 28. Configure the startup probe

Focus: allowing a process time to initialize. Change: API Deployment probe settings.

- [ ] Add a startup probe and explain its period, timeout, and failure threshold.
- [ ] Simulate slow application startup and observe how startup probing affects readiness and liveness checks.

Check: a normally slow startup gets time to finish, and a process that never starts eventually fails the probe.

### 29. Configure the readiness probe

Focus: deciding whether a Pod should receive traffic. Change: API Deployment probe settings.

- [ ] Add a readiness probe that reflects the API's ability to serve its database-backed routes, using short dependency timeouts.
- [ ] Make a replica unready and observe its exclusion from ready Service endpoints.
- [ ] Restore readiness and observe traffic eligibility return.

Check: an unready replica stops receiving new Service traffic without a readiness failure itself restarting the process.

### 30. Configure the liveness probe

Focus: detecting a stuck process. Change: API Deployment probe settings.

- [ ] Add a lightweight process-health probe with suitable timeouts and thresholds.
- [ ] Simulate a liveness failure and inspect restart counts, events, and previous container logs.
- [ ] Verify that a database outage does not itself fail liveness and cause repeated API restarts.

Check: process failures and dependency failures produce different, explainable behavior.

## Part 6: resource use and operating the lab

### 31. Set resource requests

Focus: scheduling capacity and the CPU utilization denominator. Change: workload resource requests.

- [ ] Choose CPU and memory requests for API and database containers from the host budget and observed usage.
- [ ] Compare node capacity, allocatable resources, requested resources, and actual usage.
- [ ] Temporarily make an API request too large and diagnose the resulting Pending Pod from scheduler events, then restore it.

Check: the API and database fit on their intended workers, and a request is understood as distinct from a hard usage ceiling.

### 32. Set limits and configure application parallelism

Focus: resource ceilings and application capacity. Change: resource limits and API runtime settings.

- [ ] Choose and explain CPU and memory limits separately from requests. Observe CPU throttling and a controlled memory-limit failure.
- [ ] Choose application parallelism, such as threads or worker processes, to suit the CPU budget of each API Pod. Keep configuration explicit and record the choice.
- [ ] Verify that the CPU workload can use its assigned budget; explain application runtime constraints separately from Kubernetes limits.
- [ ] Document that one Pod can use multiple cores, while this local cluster still shares a finite pool of host resources.

Check: usage, limits, and worker count agree. Enough capacity remains for PostgreSQL, probes, Kubernetes components, and load generation.

### 33. Require API replicas to use different workers

Focus: node eligibility and required Pod anti-affinity. Change: API Deployment scheduling settings.

- [ ] Select the eligible workers using their labels, without pinning API replicas to individual node names.
- [ ] Add required API Pod anti-affinity using `kubernetes.io/hostname` and the API label selector.
- [ ] Manually scale from one to three API replicas and inspect `kubectl get pods -o wide`.
- [ ] Temporarily request a fourth replica and diagnose why it stays Pending, then restore one replica.

Check: at most one matching API Pod runs per eligible worker. The rule does not prevent PostgreSQL or system Pods from sharing those workers.

### 34. Expose the API for host traffic

Focus: Service types and the host-to-cluster boundary. Change: API Service type and ports.

- [ ] Change the API Service to NodePort 30080 and verify WSL can reach a worker VM on that port through the private network.
- [ ] Trace WSL traffic to a worker VM's private IP:30080, through the NodePort Service, to a ready API Pod. Keep the Kubernetes API endpoint on port 6443 separate.
- [ ] Compare `kubectl port-forward` with Service traffic. Use the VM NodePort for multi-replica load tests because a port-forward session targets one selected Pod.
- [ ] Use Pod identity responses and fresh connections to observe distribution; do not assume every request rotates to a different Pod.

Check: the WSL workstation can reach the Service at a worker VM's private IP on port 30080, while PostgreSQL stays internal to the cluster.

### 35. Practice rollouts, shutdown, and rollback

Focus: Deployment update strategy and lifecycle. Change: API Deployment rollout and termination settings.

- [ ] Build and publish a new image tag, perform a rollout, watch its status, and roll back a deliberately broken version.
- [ ] Handle termination gracefully and choose a suitable termination grace period.
- [ ] Account for required anti-affinity at three replicas: an extra surge Pod cannot fit on the three occupied workers.
- [ ] Use an explained strategy such as `maxSurge: 0` and `maxUnavailable: 1`. Record the temporary capacity reduction and the outage when updating a single replica with that strategy.

Check: updates finish without a scheduling deadlock. Their availability tradeoff is documented and observed.

### 36. Back up and restore PostgreSQL

Focus: recovery and a one-off backup Job. Planned file: `k8s/base/db-backup-job.yaml`.

- [ ] Produce a logical backup and export it to an ignored workstation directory outside the guest disks.
- [ ] Restore into a separate test database so the exercise can verify recovery without overwriting the active dataset.
- [ ] Verify representative records and counts through SQL or API checks, and document the exact backup and restore procedure.
- [ ] Explain how a backup differs from persistence and replication.

Check: a backup has been restored successfully; creating a dump alone does not complete this step.

### 37. Schedule a backup with a CronJob

Focus: scheduled tasks. Planned file: `k8s/base/db-backup-cronjob.yaml`.

- [ ] Reuse the backup operation in a CronJob and explain schedule timezone, concurrency policy, history limits, and suspension.
- [ ] Trigger and inspect a run, export its artifact outside the cluster, and document the artifact-retention behavior.
- [ ] Suspend the schedule when the lab is idle. State clearly if export to the host remains manual.

Check: a scheduled Job produces a retrievable backup, and in-cluster artifacts are not described as protection against cluster deletion.

### 38. Learn ServiceAccounts and RBAC

Focus: workload identity and Kubernetes API permissions. Planned files: separate ServiceAccount, Role, and RoleBinding manifests.

- [ ] Give the API a dedicated ServiceAccount and disable automatic token mounting because the API does not need Kubernetes API access.
- [ ] Create a separate read-only lab inspection identity with a narrow namespace Role and RoleBinding, excluding Secret contents.
- [ ] Use `kubectl auth can-i` to compare allowed inspection operations with rejected writes. Explain how this differs from application login or database permissions.

Check: the inspection identity can perform its documented reads and cannot change workloads or read Secret contents.

### 39. Practice troubleshooting and worker maintenance

Focus: reading evidence before changing configuration. Planned notes: `docs/lessons/`.

- [ ] Diagnose a bad image tag, process crash, failed probe, Service selector error, and storage or scheduling problem.
- [ ] Practice `get`, `describe`, `logs`, `logs --previous`, `exec`, and event inspection. Use an image-pull failure only after explaining the local image workflow.
- [ ] Cordon and drain a worker for an API exercise, inspect replacement scheduling, and uncordon it afterward.
- [ ] Respect the database's local storage placement. Record why draining its worker does not demonstrate automatic database failover.
- [ ] Use hypervisor controls for an explained guest power-loss or network-disconnection exercise, with console/host-side recovery available. Observe actual NodeNotReady and eviction timing, then restore connectivity and verify recovery.
- [ ] After connectivity is reliable, optionally introduce bounded delay or packet loss on a lab guest interface to simulate remote links. Record and restore its prior configuration; keep the operator and unrelated networks untouched.

Check: each failure has a recorded symptom, useful command, cause, and fix. At full placement, replacement API Pods may wait for an eligible worker.

### 40. Introduce Kustomize after plain YAML

Focus: organizing existing manifests. Planned file: `k8s/base/kustomization.yaml` and narrowly scoped experiment overlays if needed.

- [ ] Add Kustomize around resources already understood and deployed individually.
- [ ] Inspect rendered YAML with `kubectl kustomize`, preview changes with `kubectl diff -k`, and apply deliberately with `kubectl apply -k`.
- [ ] Keep ordered migration, seed, and recovery Jobs explicit; including a Job in a bundle does not provide a full task-ordering workflow.
- [ ] Explain plain manifests, Kustomize bases/patches, and Helm charts/values. Keep Helm chart authoring outside the initial implementation.

Check: the rendered objects are understandable and equivalent to the intended individual manifests. The abstraction does not hide what will be created.

## Part 7: metrics and the final autoscaling experiment

### 41. Install and inspect Metrics Server

Focus: the resource-metrics pipeline. Planned notes and pinned add-on source: `environment/`.

- [ ] Install a Metrics Server release compatible with the chosen Kubernetes version and record its source and configuration.
- [ ] Inspect its Deployment, logs, and Metrics API availability. Follow the path from kubelet measurements to the resource-metrics API.
- [ ] Verify `kubectl top nodes` and `kubectl top pods` return values after metrics are collected.
- [ ] Verify Metrics Server can authenticate and validate kubelet serving certificates. Resolve serving-certificate bootstrap/trust explicitly; do not silently disable TLS verification.

Check: API CPU measurements are available. No Prometheus stack or custom-metrics adapter is needed for this first CPU-based HPA.

### 42. Measure a single-replica baseline

Focus: repeatable traffic and observable capacity. Planned location: `load/`.

- [ ] Add k6 scenarios for bounded CPU work and database-backed reads, with recorded request rate, duration, and input data.
- [ ] Run against the VM-reachable Service with one API replica. Increase load gradually and record throughput, p95 latency, error rate, Pod CPU, and node usage.
- [ ] Confirm the load generator can create the requested traffic and that database saturation or probe restarts are not obscuring the CPU experiment.
- [ ] Save the baseline and runtime/resource settings in `docs/results/`. Record each guest's CPU/RAM allocation and the physical host budget so the result can be interpreted.

Check: the first scaling scenario has measurable CPU demand and an observed baseline. A timed sleep or a slow database is not mistaken for CPU saturation.

### 43. Configure the Horizontal Pod Autoscaler

Focus: metric targets, replica bounds, and scaling behavior. Planned file: `k8s/base/api-hpa.yaml`.

- [ ] Create an `autoscaling/v2` HPA targeting the API Deployment, with `minReplicas: 1` and `maxReplicas: 3`.
- [ ] Choose an initial CPU utilization target, such as 70%, and explain that its percentage is relative to CPU requests, not the whole worker's CPU usage.
- [ ] Inspect scale-up policies and a deliberate scale-down stabilization window. Explain why actions and readiness are not instantaneous.
- [ ] Hand replica-count control to HPA: stop applying a fixed `spec.replicas` through the active Deployment manifests or overlays, and avoid manual scaling during the experiment.
- [ ] Inspect HPA conditions, events, metrics, desired replicas, and actual ready Pods before generating sustained load.

Check: the HPA has valid CPU metrics, no replica-count writer competes with it, and the one-replica idle state is stable.

### 44. Demonstrate scaling and finish the repository

Focus: the original experiment and evidence that it works.

- [ ] Start with one ready API replica, generate increasing CPU load, and observe additional ready replicas on different workers.
- [ ] Sustain enough load to reach three replicas within the configured policy, then stop traffic and observe scale-down toward one after stabilization.
- [ ] Record traffic, resource settings, replica placement, HPA events, throughput, p95 latency, and error rate. Compare with the single-replica baseline without inventing improvement claims.
- [ ] Run the database-backed scenario and explain any different bottleneck, including connection growth as replicas and processes increase.
- [ ] Add an ordered reproduction guide, command reference, selected real output, and measured results. Update README status and keep the architecture consistent with what was built.
- [ ] Recreate and verify the plain VMs and manual kubeadm cluster from their documentation. Document disk-preserving shutdown separately from deleting PVCs or VM disks, including how to preserve and restore data.

Check: another person can reproduce the experiment, see API replicas spread across workers, and understand the measured result. Shared physical hardware is acknowledged in performance conclusions.

## Completion criteria

- [ ] The learner can manually prepare Linux guests, install containerd, bootstrap the control plane, and join workers.
- [ ] The learner can explain the path from VM guests and their container runtimes to Kubernetes resources and application processes.
- [ ] The lab is operated through understood `kubectl` commands and readable configuration files.
- [ ] The API uses persistent synthetic banking data, and backup restoration has been verified.
- [ ] HPA scales API replicas across existing worker nodes under load and reduces them afterward.
- [ ] Results, limitations, recovery steps, and reproduction instructions are recorded accurately.

## Deferred work

Database read replicas, automated failover, and sharding can follow the completed lab. They require database-specific work beyond increasing a StatefulSet replica count.

Kafka was the alternative application considered at the start. Do not add Kafka, consumers, queue-based scaling, or KEDA during this plan. Revisit that direction only after the API/database lab and its autoscaling experiment are complete and the owner chooses to continue with it.

Automatic node provisioning, cloud deployment, an ingress controller, and enforced NetworkPolicies with a suitable network plugin are also later exercises. The initial experiment uses a fixed VM worker pool and a NodePort reachable from the WSL operator workstation.

## References

- [Manual kubeadm cluster installation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [Container runtime configuration](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [libvirt VM lifecycle](https://ubuntu.com/server/docs/how-to/virtualisation/libvirt/)
- [Kubernetes resource management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Pod placement and anti-affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Horizontal Pod Autoscaler walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [Metrics Server](https://kubernetes-sigs.github.io/metrics-server/)
- [Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [k6 load test types](https://grafana.com/docs/k6/latest/testing-guides/test-types/)
