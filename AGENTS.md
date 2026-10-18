# Context for AI collaborators

## Purpose and the owner's starting point

This repository is a hands-on Kubernetes learning project. The owner knows some terminology and has seen configuration, but is starting with little practical `kubectl` experience. They want to become comfortable deploying, inspecting, changing, troubleshooting, and scaling applications from a terminal.

The owner wants to understand the actual files and settings. Keep logical Kubernetes topics separate so they can see what each change does. A working application matters, and so does being able to explain how it got there.

The repository may become public as part of the owner's GitHub portfolio. Documentation should give an outside reader a clear picture of the work and its current state. Describe observed results accurately; do not claim completed features, performance gains, production readiness, or banking capabilities that have not been implemented and verified.

## Read these files first

- `README.md` describes the project for an outside reader.
- `ARCHITECTURE.md` contains a small diagram of the target architecture.
- `TODO.md` is the ordered implementation and learning plan, including checks and deferred work.

The owner has confirmed that Step 01, host/workspace preparation, is complete. Ubuntu is installed and initialized with Docker Desktop integration. The repository contains planning documents, local fixture configuration, and lesson guides. Lesson 02 is ready for the owner to follow; its kind configuration is shown in the guide for the owner to create manually. No kind clusters existed at the latest inspection. Application code and load tests have not been implemented. Inspect actual files and task status when resuming.

The setup observations are recorded in Lesson 01: Ubuntu 26.04.1 on WSL 2, 32 logical CPUs, about 15 GiB of WSL-visible RAM, Linux Git 2.53.0, Docker client/server 29.7.2, kind 0.33.0, and kubectl 1.36.1. Git and kind are installed in Ubuntu; Docker and kubectl are Linux executables shared through Docker Desktop integration. Docker Desktop's internal distribution is not the operator workstation.

## The experiment the owner selected

Use one control-plane node and three worker nodes in a local kind cluster. kind runs nodes as Docker containers with separate node identities and network addresses, while all nodes share the same physical host resources.

The intended application is a small REST API backed by one PostgreSQL instance containing fictional banking data.

The final experiment is:

1. Start with one API Pod on one worker. The other workers already exist and have spare API capacity.
2. Generate increasing traffic and observe API CPU demand.
3. Let HPA increase the API Deployment's replica count.
4. Place the additional API Pods on different workers and route traffic through a Service.
5. Reduce traffic and observe HPA scale back down after the configured stabilization behavior.

Keep the normal range at one to three API replicas. Require at most one matching API Pod per eligible worker with Pod anti-affinity. This restriction applies to API replicas; the database and system workloads can share a worker with an API Pod.

The project scales application Pods across a fixed worker pool. Provisioning new worker machines automatically is outside the initial experiment. Do not quietly replace this goal with several API replicas on one worker or a single-node cluster.

## Important conceptual distinctions

- One Pod runs on one node. Multiple instances of an application across machines means multiple Pods, not one Pod spanning nodes.
- One Pod can use multiple CPU cores and much of a node's available capacity if its application parallelism and resource configuration allow it. Kubernetes does not impose a universal one-core-per-Pod rule.
- CPU requests influence scheduling and the denominator for CPU utilization targets. CPU limits constrain usage. Neither should be confused with the worker's entire CPU capacity.
- HPA determines a desired replica count. The Deployment and ReplicaSet controllers maintain replicas, the scheduler assigns new Pods to nodes, and Services route traffic to eligible endpoints.
- CPU-based HPA uses application resource metrics. It does not simply wait for a worker's CPU graph to reach 100%.
- Container restarts, Pod replacement, adding replicas, and adding nodes are separate operations.
- More replicas help when there is usable capacity and the workload can benefit from parallel instances. A shared database, the host, or the load generator can become the limiting factor.
- Local Docker nodes simulate node boundaries. They do not provide independent physical failure domains or extra hardware.

The owner's questions about one Pod using a whole machine were central to the design discussion. Preserve the direct answer: it can. Explain specific application or resource limits when they matter, without implying that adding same-node replicas is always necessary.

## Initial technology choices

These are implementation defaults, not claims that the owner explicitly selected each technology:

| Concern | Default |
| --- | --- |
| Host workflow | Linux Bash in the owner's WSL 2 distribution; Docker Desktop WSL integration with Linux containers |
| Local Kubernetes | kind, one control-plane node and three workers |
| Cluster operations | `kubectl`, individual YAML resources first |
| Application | Language and framework undecided |
| Database | PostgreSQL |
| Load generation | k6 against the API Service |
| Metrics and scaling | Metrics Server and an `autoscaling/v2` HPA |
| Manifest organization | Kustomize after the raw manifests are understood |

The owner will choose the API language and framework later. Keep preparation language-neutral until that choice is made; do not select a default on their behalf. Choose compatible tool versions during implementation and record them. Avoid adding dependencies merely to make the application more elaborate.

## Versioned local lab configuration and credentials

The owner explicitly wants `.env` and credentials created solely for this disposable local lab to be versioned. Treat them as intentionally public fixtures. Include local database passwords and local Kubernetes Secret definitions in the reproducible project configuration by default. A resource being named `Secret`, or a variable containing `PASSWORD`, is not by itself a reason to exclude it from Git.

Do not add blanket `.env` or local-credential ignore rules, replace working fixture values with placeholders, or insist on a separate untracked secrets workflow. Keep the committed values usable for the documented local setup. An `.env.example` may be useful later, but it must not replace the requested working `.env`.

These values belong only to disposable local services and fictional data. If there is concrete evidence that a value authorizes access to another system, identify the value's purpose and capability and bring that concern to the owner. Examples include a real GitHub/cloud token, a personal SSH private key, or credentials reused by an external database. Explain the actual reason for an exception instead of giving a generic warning based on the file name or the word secret. Do not silently change this policy.

Generated kubeconfigs remain ignored because they contain per-cluster endpoints and access data, change when a cluster is recreated, and are generated by kind rather than being portable source configuration. This is an explicit generated-file exception, not a ban on committing local application credentials. Backups and raw runtime output remain ignored as generated artifacts.

The root `.env` is the starting source of local database settings. Explain each later command or tool that reads it. Neither `kubectl` nor ordinary Kubernetes YAML automatically loads or substitutes `.env` values.

## Linux terminal workflow

All learning commands, scripts, installation instructions, and examples must use Linux tooling and Bash in WSL 2. Do not give PowerShell, CMD, Windows executable, or Git Bash equivalents by default. The owner already has WSL and wants to operate the lab from that Linux environment. If a Windows-side setting is genuinely required, explain it specifically; keep routine commands in Linux.

Use the WSL distribution as the operator workstation for Git, Docker CLI, kind, and `kubectl`. Docker Desktop may provide the engine through WSL integration. Do not install a second Docker daemon inside WSL on top of that setup without first establishing a concrete reason.

The existing checkout is normally accessible from WSL at `/mnt/c/Me/Dev/learning/k8s_commands`. Use Linux paths in commands. A repository under the WSL home directory can be considered for Linux filesystem performance later; do not move or duplicate this checkout without the owner's request.

Treat Ubuntu as the owner's persistent personal Linux computer, used for other work as well as this lab. Keep project files in this checkout and keep generated files in clearly named, ignored project locations. Reuse existing tools; do not install packages just to check Markdown or introduce a second copy of an available CLI. Avoid scattering downloaded binaries, archives, scripts, or logs across the home directory.

For this lab, generate the kubeconfig at `cluster/bank-lab.kubeconfig` with kind's explicit `--kubeconfig` flag. Pass that path to `kubectl` in lesson commands. Do not merge lab access into the owner's personal `~/.kube/config`, change shell startup files, or persist environment variables as a side effect of a lesson. If temporary files are necessary, use a clearly scoped temporary location and remove only the files created for that task.

Explain what each lesson creates and where it lives, including Docker images, node containers, networks, and generated configuration. Cleanup must target the named `bank-lab` cluster or specific project-owned artifacts. Never use broad Docker pruning, remove a shared Docker network, stop unrelated containers, or change host-wide settings as routine lab cleanup. Closing a terminal does not stop the cluster; explain the lifecycle and the data removed by any teardown command.

There are separate terminal contexts to teach:

- WSL workstation: normal Git, Docker, kind, and Kubernetes administration.
- kind node container: occasional inspection with `docker exec -it <node-container> bash`.
- Application container in a Pod: inspection with `kubectl exec -it -n bank-lab <pod-name> -- sh`, specifying a container when needed.

Shell examples assume that the image contains the named shell. Minimal images may require a debug container instead. These commands open processes inside running containers; they do not require SSH servers. Keep durable configuration in Git and apply it through Kubernetes rather than making lasting setup changes by hand inside node or application containers.

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

The kind configuration belongs to the infrastructure layer. Workload manifests belong to the application layer. Do not use Docker Compose to manage the final Kubernetes workloads or hide all setup in a single script before teaching the individual operations.

### Networking and traffic

Use Services and cluster DNS for application connections. Do not hardcode Pod or node IPs into database connection settings.

The planned host entry point is loopback port 8080 mapped to a node's port 30080, with the API exposed by NodePort. Verify this route from the WSL operator terminal on the actual Docker setup. Keep PostgreSQL internal to the cluster.

`kubectl port-forward` is useful for inspection but selects a Pod for a session, including when invoked against a Service. Use the mapped Service entry point for load tests that are meant to exercise multiple replicas. Connection reuse can keep requests on an endpoint; do not require strict per-request rotation to prove a Service works.

### Persistence, migrations, and recovery

Start with one PostgreSQL Pod in a StatefulSet, a governing headless Service, a normal client Service, and a PVC. Inspect the actual StorageClass and binding behavior. Pin the database to the chosen local-storage worker and explain the scheduling constraint.

Local persistent storage survives the relevant Pod lifecycle operations but is tied to a worker and the cluster's storage arrangement. Do not promise that moving the database Pod to another worker automatically moves its data. Worker-drain exercises must account for this limitation.

Run migrations and seeds as ordered, explicit Jobs with safe retry behavior. Avoid having every API replica race to initialize the database. Bundling resources with Kustomize does not replace waiting for migration completion.

Back up PostgreSQL and test a restore into a separate database. Export backups outside the kind cluster, keep them out of Git, and document whether export is manual. A scheduled backup that exists only inside the cluster is not evidence of recovery after cluster deletion. Add CronJob scheduling as its own step.

Increasing a StatefulSet's replica count does not configure PostgreSQL replication. Persistence, replication, backups, failover, and sharding solve different problems. Only single-instance persistence and tested backup/restore belong to the initial database implementation.

### Probes, resources, and placement

Teach startup, readiness, and liveness independently. Readiness may check whether database-backed routes can be served, with bounded timeouts. Liveness should reflect process health; a database outage should not itself trigger repeated API restarts. Reserve capacity and choose probe timings so the load test does not create misleading probe failures.

Budget CPU and memory for the API, database, system components, Metrics Server, and load generator. Use measured values and record requests, limits, and process count. Shared Docker hardware makes per-node capacity figures easy to misinterpret; do not claim physical capacity is multiplied by the number of node containers.

Use required API Pod anti-affinity with `kubernetes.io/hostname`, selecting the API's labels in the lab namespace. Restrict the API to eligible workers. With three eligible workers, a fourth matching API Pod is expected to remain Pending. Use that as a temporary scheduling exercise and return the normal configuration to three or fewer replicas.

### Updates and autoscaling

Required anti-affinity affects updates as well as steady-state placement. At three API replicas, all three eligible workers are occupied, so a surge Pod cannot fit. Choose an explicit rollout strategy that makes progress, such as `maxSurge: 0` and `maxUnavailable: 1`, and explain the capacity reduction. That example causes an outage during a one-replica update; document the observed tradeoff instead of claiming zero downtime.

Install a compatible, pinned Metrics Server version and verify the Metrics API before configuring HPA. If a local kind certificate exception is necessary, explain the reason and keep it specific to the lab. Do not introduce a Prometheus stack or custom metrics for the first CPU-based experiment.

Use `autoscaling/v2`, a minimum of one replica, and a maximum of three. Teach the CPU target relative to requests, metric collection delays, readiness, scaling policies, and scale-down stabilization. Keep API replica-count ownership with HPA once it is enabled; remove the fixed count from actively applied Deployment configuration and avoid manual scaling during measured runs.

Measure the one-replica baseline before enabling scaling. Record offered traffic, throughput, p95 latency, errors, CPU, ready replicas, and placement. Compare the CPU-work scenario with database-backed traffic. Account for database connections increasing with replicas and worker processes.

## How to collaborate as a tutor

Follow the owner's current request and the relevant step in `TODO.md`. If asked for the next learning step, do not implement the entire remaining plan in one response. If asked to implement a defined scope, carry out that authorized scope without repeatedly requesting permission for routine choices.

For each new concept:

1. Explain the problem it solves in this lab.
2. Identify the resource and the relevant file and fields.
3. Provide the commands to create or change it and the commands to inspect it.
4. State what the learner should observe and how to diagnose a common failure.

Prefer practical explanations and real output over long terminology lists. Introduce acronyms when first used. Separate host/Docker operations, cluster administration, application configuration, and application code so commands are easy to place mentally.

Use Linux Bash commands from the WSL operator terminal. Label commands that instead run inside a node or application container. Inspect the current Kubernetes and Docker contexts before changing resources, and distinguish routine Pod recreation from deleting stored data.

Do not start installations, create clusters, generate application code, or run load tests merely because a documentation change mentions them. Current user instructions determine the authorized work. Do not create cloud resources or start deferred topics as incidental follow-up work.

## Planned repository layout

Create these directories as the corresponding steps need them:

| Path | Purpose |
| --- | --- |
| `cluster/` | kind topology, pinned cluster add-ons, infrastructure notes |
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

Possible later extensions include PostgreSQL read replicas and failover, database sharding, automatic node provisioning, cloud deployment, or adding Kafka alongside the API. Keep them out of the initial implementation unless the owner explicitly changes the scope. An ingress controller, enforced NetworkPolicies, and Helm chart authoring can also be separate follow-up exercises.
