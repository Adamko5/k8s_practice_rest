# Implementation and learning plan

Build a local Kubernetes lab with one control-plane node, three workers, a REST API, and PostgreSQL. Finish by scaling the API automatically from one to three replicas on different workers under load.

Step 01 is complete, as confirmed by the owner. Lesson 02 is ready to follow; cluster creation is still pending. The API language and framework are deliberately undecided; the owner will choose them later. PostgreSQL and k6 remain the planned database and load-testing tools.

## How to use this plan

Work through one numbered step at a time. Each Kubernetes concept has its own step, even when several steps edit the same manifest. Inspect the resulting state before continuing.

For each step, keep a short lesson note with the command, the relevant YAML fields, the expected observation, and any useful failure encountered. Use Git checkpoints to preserve changes to shared manifests. Start with direct commands and plain YAML; add convenience scripts and Kustomize after the individual operations make sense.

Paths mentioned below are planned outputs, not files that already exist.

## Part 1: local machines and terminal basics

### 01. Prepare the host and workspace

- [x] Install and initialize a user-facing WSL 2 Linux distribution, such as Ubuntu, and enable its Docker Desktop integration.
- [x] Check the available CPU, memory, disk space, and Docker allocation before choosing resource budgets.
- [x] Verify Linux Git, Docker access through WSL integration, kind, and `kubectl` from the WSL distribution. Record compatible versions and any installation steps needed.
- [x] Standardize commands and examples on Linux Bash in WSL 2. Distinguish workstation, kind-node, and application-container terminals.
- [x] Prepare the Git workspace and minimal ignores for generated or machine-specific files. Add a working, intentionally public `.env` for disposable local credentials; keep those values committable.

Completed: the owner confirmed the host/workspace checks passed. See [Lesson 01: host and workspace](docs/lessons/01-host-and-workspace.md) for the commands and recorded setup observations.

Check: Docker can run a Linux container, tool versions are recorded, and no application or cluster has been created implicitly.

### 02. Create the simulated machines

Focus: infrastructure below Kubernetes workloads. Planned file: `cluster/kind.yaml`.

Follow [Lesson 02: create the cluster](docs/lessons/02-create-the-cluster.md). Keep lab access in the ignored `cluster/bank-lab.kubeconfig` file so personal cluster configuration stays separate.

- [ ] Define a named `bank-lab` kind cluster with one control-plane node and three worker nodes.
- [ ] Reserve a loopback-only host mapping from port 8080 to NodePort 30080 on a kind node for the later traffic experiment.
- [ ] Create the cluster with an explicit command and inspect the node containers, Docker network, and node addresses.
- [ ] Explain the difference between a node container, an application container, and a Pod. Record that all simulated machines share the host's hardware.

Check: all four node containers exist. The Docker network connects them; separate nodes do not add physical compute capacity.

### 03. Learn kubeconfig, contexts, and cluster inspection

Focus: how `kubectl` finds and talks to a cluster.

- [ ] Inspect the active context and select the lab context explicitly. Explain kubeconfig's cluster, user, and context entries, and why generated per-cluster access files are kept out of Git.
- [ ] Practice `kubectl cluster-info`, `get nodes -o wide`, `describe node`, `api-resources`, and `explain`.
- [ ] Locate the control-plane and system Pods. Identify each node's capacity, allocatable resources, and taints.

Check: every node is Ready, and it is clear which cluster a command will affect.

### 04. Create a namespace and learn labels and selectors

Focus: grouping resources and matching them. Planned file: `k8s/base/namespace.yaml`.

- [ ] Create the `bank-lab` namespace and practice explicit namespace flags.
- [ ] Choose consistent application labels for the API and database. Explain how selectors match labels.
- [ ] Label the three workers as eligible for the API and choose one worker for local PostgreSQL storage.
- [ ] Practice filtering resources by namespace and label, including inspecting resources across all namespaces.

Check: the namespace exists and worker labels identify the intended placement without hardcoding application connections to node IPs.

## Part 2: the application and its image

### 05. Define fictional banking data

Focus: a small data model for the lab. Planned location: `db/`.

- [ ] Define synthetic customers, accounts, account balances, and transaction history with clear relationships.
- [ ] Use integer minor units for money, an explicit currency, and consistent seed balances and history. Keep the initial dataset to one currency.
- [ ] Specify deterministic seed records and pagination so tests and load runs can use repeatable inputs.
- [ ] Keep personal information fictional, use example email domains, and omit real payment credentials or bank integrations.

Check: a short data dictionary explains the records and relationships. Transfers, a complete financial ledger, and payment processing are outside the initial API.

### 06. Implement the REST API locally

Focus: application behavior. Planned location: `app/`.

- [ ] Choose the API language and framework with the owner, then set up and document the application tooling.
- [ ] Implement customer create/read/update operations, account and balance reads, and paginated transaction-history reads.
- [ ] Add separate startup, readiness, and liveness endpoints, plus a response header or endpoint identifying the serving Pod.
- [ ] Add a bounded CPU-work endpoint for the scaling experiment. Put limits on the work per request; sleeping is not a CPU workload.
- [ ] Add meaningful tests for validation, stored data, and error responses. Plan database integration checks for when PostgreSQL is available.
- [ ] Keep the process able to start for health and identity inspection before database wiring; database-dependent endpoints should report unavailability honestly.

Check: the process starts locally, basic endpoints work, and CPU work is measurable. Banking operations will be verified against PostgreSQL in step 15.

### 07. Build and deliver the container image

Focus: the artifact Kubernetes runs. Planned outputs: `app/Dockerfile`, dependency lock file, and `.dockerignore`.

- [ ] Build a versioned API image with an explicit command, a small runtime, and a non-root application user.
- [ ] Run and inspect it directly with Docker, including logs, port mapping, and process shutdown.
- [ ] Load the image into the named kind cluster and explain image tags, pull policy, and local image availability on workers.

Check: the container serves the same basic endpoints as the local process, and every worker can use the chosen image tag.

## Part 3: workloads, configuration, networking, and state

### 08. Create the API Deployment

Focus: desired state, Pods, and ReplicaSets. Planned file: `k8s/base/api-deployment.yaml`.

- [ ] Create a Deployment with one API replica and the local image.
- [ ] Explain `apiVersion`, `kind`, metadata, selector, Pod template, container image, and container port. Distinguish declaring a port from exposing it.
- [ ] Inspect the Deployment, ReplicaSet, and Pod ownership chain. Delete the API Pod and watch its replacement.

Check: one API Pod runs and is recreated by its controller. Database-dependent routes remain unavailable until step 15.

### 09. Add non-secret configuration with a ConfigMap

Focus: application settings. Planned file: `k8s/base/api-configmap.yaml`.

- [ ] Move settings such as database host, database name, log level, and bounded-work configuration into a ConfigMap.
- [ ] Wire the settings into the Deployment and explain environment-variable versus mounted-file configuration.
- [ ] Change one setting and observe when it reaches the running application, including the restart needed for environment variables.

Check: a configuration change can be applied and verified without rebuilding the image.

### 10. Add credentials with a Secret

Focus: Kubernetes Secret resources using intentionally public lab credentials. Planned output: reproducible Secret creation from versioned local values.

- [ ] Use the committed `.env` values to create the local database Secret and reference it from the relevant workloads. Explain the explicit command that reads `.env`.
- [ ] Keep disposable local credentials and their configuration versioned. Explain that a Kubernetes Secret is a resource type and base64 encoding is not encryption.
- [ ] Practice inspecting metadata, references, and the local fixture values. If a value actually grants access outside this disposable lab, explain that concrete exception to the owner.

Check: workloads can reference the Secret, and a fresh checkout contains the working local fixture values needed to recreate it.

### 11. Add Services and test cluster DNS

Focus: stable addresses and traffic routing. Planned files: `k8s/base/api-service.yaml` and `k8s/base/postgres-service.yaml`.

- [ ] Create a ClusterIP Service for the API and another for PostgreSQL.
- [ ] Explain `selector`, `port`, `targetPort`, and Service DNS names. Inspect EndpointSlices.
- [ ] Use a temporary diagnostic Pod to resolve DNS and reach the API through its Service.
- [ ] Break and fix a selector to observe the difference between a running Pod and a Service with usable endpoints.

Check: the API is reachable inside the cluster by Service name. The PostgreSQL Service will gain an endpoint after step 13.

### 12. Add persistent storage

Focus: StorageClass, PersistentVolume, and PersistentVolumeClaim. Planned file: `k8s/base/postgres-pvc.yaml`.

- [ ] Inspect the cluster's storage provisioner and StorageClass. Install a compatible local provisioner only if one is missing.
- [ ] Create a database PVC and explain provisioning, access mode, binding mode, capacity, and reclaim policy.
- [ ] Inspect how the chosen provisioner stores data on a worker. Explain why a claim may wait for its consuming Pod before binding.
- [ ] Document the difference between Pod deletion, PVC deletion, node loss, and cluster deletion for this storage setup.

Check: the storage path and data-loss boundaries are understood. If binding waits for a consumer, verify that it binds in step 13.

### 13. Deploy PostgreSQL with a StatefulSet

Focus: a stateful workload. Planned files: `k8s/base/postgres-statefulset.yaml` and `k8s/base/postgres-headless-service.yaml`.

- [ ] Create one PostgreSQL instance, mount its PVC, reference its credentials, and select the worker chosen for storage.
- [ ] Add its governing headless Service and explain how that differs from the normal database client Service.
- [ ] Explain stable Pod identity and compare the StatefulSet with the API Deployment. Keep the database replica count at one.
- [ ] Write a test record, recreate the database Pod, and verify the record survives.

Check: PostgreSQL is reachable through the client Service and retains data across Pod recreation. No database replication or automatic storage failover is claimed.

### 14. Run migrations and seed data with Jobs

Focus: tasks that complete. Planned files: `k8s/base/db-migrate-job.yaml` and `k8s/base/db-seed-job.yaml`.

- [ ] Implement versioned database migrations and a repeatable seed operation.
- [ ] Run migrations and seeds as separate Jobs with explicit ordering, completion checks, and logs.
- [ ] Explain Job retry behavior and why migration code must handle retries safely. Avoid running migrations independently in every API replica.

Check: schema and synthetic data exist. Repeating the seed operation behaves as documented without duplicating records unexpectedly.

### 15. Connect the API to PostgreSQL

Focus: the complete request path and shared application state.

- [ ] Wire database settings and credentials into the API, using the database Service name.
- [ ] Set bounded connection pools and timeouts. Account for the product of API replicas, worker processes, and connections per process.
- [ ] Exercise customer writes, account reads, pagination, and missing-record errors against the real database.
- [ ] Verify stored data survives API Pod replacement. Keep shared business state in PostgreSQL.

Check: requests travel from the API to PostgreSQL and return the expected synthetic records. Integration checks pass.

### 16. Configure the startup probe

Focus: allowing a process time to initialize. Change: API Deployment probe settings.

- [ ] Add a startup probe and explain its period, timeout, and failure threshold.
- [ ] Simulate slow application startup and observe how startup probing affects readiness and liveness checks.

Check: a normally slow startup gets time to finish, and a process that never starts eventually fails the probe.

### 17. Configure the readiness probe

Focus: deciding whether a Pod should receive traffic. Change: API Deployment probe settings.

- [ ] Add a readiness probe that reflects the API's ability to serve its database-backed routes, using short dependency timeouts.
- [ ] Make a replica unready and observe its exclusion from ready Service endpoints.
- [ ] Restore readiness and observe traffic eligibility return.

Check: an unready replica stops receiving new Service traffic without a readiness failure itself restarting the process.

### 18. Configure the liveness probe

Focus: detecting a stuck process. Change: API Deployment probe settings.

- [ ] Add a lightweight process-health probe with suitable timeouts and thresholds.
- [ ] Simulate a liveness failure and inspect restart counts, events, and previous container logs.
- [ ] Verify that a database outage does not itself fail liveness and cause repeated API restarts.

Check: process failures and dependency failures produce different, explainable behavior.

## Part 4: resource use and operating the lab

### 19. Set resource requests

Focus: scheduling capacity and the CPU utilization denominator. Change: workload resource requests.

- [ ] Choose CPU and memory requests for API and database containers from the host budget and observed usage.
- [ ] Compare node capacity, allocatable resources, requested resources, and actual usage.
- [ ] Temporarily make an API request too large and diagnose the resulting Pending Pod from scheduler events, then restore it.

Check: the API and database fit on their intended workers, and a request is understood as distinct from a hard usage ceiling.

### 20. Set limits and configure application parallelism

Focus: resource ceilings and application capacity. Change: resource limits and API runtime settings.

- [ ] Choose and explain CPU and memory limits separately from requests. Observe CPU throttling and a controlled memory-limit failure.
- [ ] Choose application parallelism, such as threads or worker processes, to suit the CPU budget of each API Pod. Keep configuration explicit and record the choice.
- [ ] Verify that the CPU workload can use its assigned budget; explain application runtime constraints separately from Kubernetes limits.
- [ ] Document that one Pod can use multiple cores, while this local cluster still shares a finite pool of host resources.

Check: usage, limits, and worker count agree. Enough capacity remains for PostgreSQL, probes, Kubernetes components, and load generation.

### 21. Require API replicas to use different workers

Focus: node eligibility and required Pod anti-affinity. Change: API Deployment scheduling settings.

- [ ] Select the eligible workers using their labels, without pinning API replicas to individual node names.
- [ ] Add required API Pod anti-affinity using `kubernetes.io/hostname` and the API label selector.
- [ ] Manually scale from one to three API replicas and inspect `kubectl get pods -o wide`.
- [ ] Temporarily request a fourth replica and diagnose why it stays Pending, then restore one replica.

Check: at most one matching API Pod runs per eligible worker. The rule does not prevent PostgreSQL or system Pods from sharing those workers.

### 22. Expose the API for host traffic

Focus: Service types and the host-to-cluster boundary. Change: API Service type and ports.

- [ ] Change the API Service to NodePort 30080 and test the loopback mapping reserved in step 02.
- [ ] Trace host port 8080 through Docker, the node's NodePort, the Service, and a ready API Pod.
- [ ] Compare `kubectl port-forward` with Service traffic. Use the mapped NodePort for multi-replica load tests because a port-forward session targets one selected Pod.
- [ ] Use Pod identity responses and fresh connections to observe distribution; do not assume every request rotates to a different Pod.

Check: the host can reach the Service at `localhost:8080`, while PostgreSQL stays internal to the cluster.

### 23. Practice rollouts, shutdown, and rollback

Focus: Deployment update strategy and lifecycle. Change: API Deployment rollout and termination settings.

- [ ] Build and load a new image tag, perform a rollout, watch its status, and roll back a deliberately broken version.
- [ ] Handle termination gracefully and choose a suitable termination grace period.
- [ ] Account for required anti-affinity at three replicas: an extra surge Pod cannot fit on the three occupied workers.
- [ ] Use an explained strategy such as `maxSurge: 0` and `maxUnavailable: 1`. Record the temporary capacity reduction and the outage when updating a single replica with that strategy.

Check: updates finish without a scheduling deadlock. Their availability tradeoff is documented and observed.

### 24. Back up and restore PostgreSQL

Focus: recovery and a one-off backup Job. Planned file: `k8s/base/db-backup-job.yaml`.

- [ ] Produce a logical backup and export it to an ignored host directory outside the kind cluster.
- [ ] Restore into a separate test database so the exercise can verify recovery without overwriting the active dataset.
- [ ] Verify representative records and counts through SQL or API checks, and document the exact backup and restore procedure.
- [ ] Explain how a backup differs from persistence and replication.

Check: a backup has been restored successfully; creating a dump alone does not complete this step.

### 25. Schedule a backup with a CronJob

Focus: scheduled tasks. Planned file: `k8s/base/db-backup-cronjob.yaml`.

- [ ] Reuse the backup operation in a CronJob and explain schedule timezone, concurrency policy, history limits, and suspension.
- [ ] Trigger and inspect a run, export its artifact outside the cluster, and document the artifact-retention behavior.
- [ ] Suspend the schedule when the lab is idle. State clearly if export to the host remains manual.

Check: a scheduled Job produces a retrievable backup, and in-cluster artifacts are not described as protection against cluster deletion.

### 26. Learn ServiceAccounts and RBAC

Focus: workload identity and Kubernetes API permissions. Planned files: separate ServiceAccount, Role, and RoleBinding manifests.

- [ ] Give the API a dedicated ServiceAccount and disable automatic token mounting because the API does not need Kubernetes API access.
- [ ] Create a separate read-only lab inspection identity with a narrow namespace Role and RoleBinding, excluding Secret contents.
- [ ] Use `kubectl auth can-i` to compare allowed inspection operations with rejected writes. Explain how this differs from application login or database permissions.

Check: the inspection identity can perform its documented reads and cannot change workloads or read Secret contents.

### 27. Practice troubleshooting and worker maintenance

Focus: reading evidence before changing configuration. Planned notes: `docs/lessons/`.

- [ ] Diagnose a bad image tag, process crash, failed probe, Service selector error, and storage or scheduling problem.
- [ ] Practice `get`, `describe`, `logs`, `logs --previous`, `exec`, and event inspection. Use an image-pull failure only after explaining the local image workflow.
- [ ] Cordon and drain a worker for an API exercise, inspect replacement scheduling, and uncordon it afterward.
- [ ] Respect the database's local storage placement. Record why draining its worker does not demonstrate automatic database failover.

Check: each failure has a recorded symptom, useful command, cause, and fix. At full placement, replacement API Pods may wait for an eligible worker.

### 28. Introduce Kustomize after plain YAML

Focus: organizing existing manifests. Planned file: `k8s/base/kustomization.yaml` and narrowly scoped experiment overlays if needed.

- [ ] Add Kustomize around resources already understood and deployed individually.
- [ ] Inspect rendered YAML with `kubectl kustomize`, preview changes with `kubectl diff -k`, and apply deliberately with `kubectl apply -k`.
- [ ] Keep ordered migration, seed, and recovery Jobs explicit; including a Job in a bundle does not provide a full task-ordering workflow.
- [ ] Explain plain manifests, Kustomize bases/patches, and Helm charts/values. Keep Helm chart authoring outside the initial implementation.

Check: the rendered objects are understandable and equivalent to the intended individual manifests. The abstraction does not hide what will be created.

## Part 5: metrics and the final autoscaling experiment

### 29. Install and inspect Metrics Server

Focus: the resource-metrics pipeline. Planned notes and pinned add-on source: `cluster/`.

- [ ] Install a Metrics Server release compatible with the chosen Kubernetes version and record its source and configuration.
- [ ] Inspect its Deployment, logs, and Metrics API availability. Follow the path from kubelet measurements to the resource-metrics API.
- [ ] Verify `kubectl top nodes` and `kubectl top pods` return values after metrics are collected.
- [ ] If kind requires a kubelet certificate workaround, explain and isolate it as a local-lab exception; do not copy it into general deployment guidance.

Check: API CPU measurements are available. No Prometheus stack or custom-metrics adapter is needed for this first CPU-based HPA.

### 30. Measure a single-replica baseline

Focus: repeatable traffic and observable capacity. Planned location: `load/`.

- [ ] Add k6 scenarios for bounded CPU work and database-backed reads, with recorded request rate, duration, and input data.
- [ ] Run against the host-mapped Service with one API replica. Increase load gradually and record throughput, p95 latency, error rate, Pod CPU, and node usage.
- [ ] Confirm the load generator can create the requested traffic and that database saturation or probe restarts are not obscuring the CPU experiment.
- [ ] Save the baseline and runtime/resource settings in `docs/results/`. Record the host and Docker allocation so the result can be interpreted.

Check: the first scaling scenario has measurable CPU demand and an observed baseline. A timed sleep or a slow database is not mistaken for CPU saturation.

### 31. Configure the Horizontal Pod Autoscaler

Focus: metric targets, replica bounds, and scaling behavior. Planned file: `k8s/base/api-hpa.yaml`.

- [ ] Create an `autoscaling/v2` HPA targeting the API Deployment, with `minReplicas: 1` and `maxReplicas: 3`.
- [ ] Choose an initial CPU utilization target, such as 70%, and explain that its percentage is relative to CPU requests, not the whole worker's CPU usage.
- [ ] Inspect scale-up policies and a deliberate scale-down stabilization window. Explain why actions and readiness are not instantaneous.
- [ ] Hand replica-count control to HPA: stop applying a fixed `spec.replicas` through the active Deployment manifests or overlays, and avoid manual scaling during the experiment.
- [ ] Inspect HPA conditions, events, metrics, desired replicas, and actual ready Pods before generating sustained load.

Check: the HPA has valid CPU metrics, no replica-count writer competes with it, and the one-replica idle state is stable.

### 32. Demonstrate scaling and finish the repository

Focus: the original experiment and evidence that it works.

- [ ] Start with one ready API replica, generate increasing CPU load, and observe additional ready replicas on different workers.
- [ ] Sustain enough load to reach three replicas within the configured policy, then stop traffic and observe scale-down toward one after stabilization.
- [ ] Record traffic, resource settings, replica placement, HPA events, throughput, p95 latency, and error rate. Compare with the single-replica baseline without inventing improvement claims.
- [ ] Run the database-backed scenario and explain any different bottleneck, including connection growth as replicas and processes increase.
- [ ] Add an ordered reproduction guide, command reference, selected real output, and measured results. Update README status and keep the architecture consistent with what was built.
- [ ] Recreate and verify the lab from its documentation. Document non-destructive stopping separately from PVC or cluster deletion, including how to preserve and restore data.

Check: another person can reproduce the experiment, see API replicas spread across workers, and understand the measured result. Local shared hardware is acknowledged in performance conclusions.

## Completion criteria

- [ ] The learner can explain the path from Docker node containers to Kubernetes resources and application processes.
- [ ] The lab is operated through understood `kubectl` commands and readable configuration files.
- [ ] The API uses persistent synthetic banking data, and backup restoration has been verified.
- [ ] HPA scales API replicas across existing worker nodes under load and reduces them afterward.
- [ ] Results, limitations, recovery steps, and reproduction instructions are recorded accurately.

## Deferred work

Database read replicas, automated failover, and sharding can follow the completed lab. They require database-specific work beyond increasing a StatefulSet replica count.

Kafka was the alternative application considered at the start. Do not add Kafka, consumers, queue-based scaling, or KEDA during this plan. Revisit that direction only after the API/database lab and its autoscaling experiment are complete and the owner chooses to continue with it.

Automatic node provisioning, cloud deployment, an ingress controller, and enforced NetworkPolicies with a suitable network plugin are also later exercises. The initial experiment uses a fixed worker pool and a local NodePort entry point.

## References

- [kind configuration](https://kind.sigs.k8s.io/docs/user/configuration/)
- [Kubernetes resource management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Pod placement and anti-affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Horizontal Pod Autoscaler walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [Metrics Server](https://kubernetes-sigs.github.io/metrics-server/)
- [Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [k6 load test types](https://grafana.com/docs/k6/latest/testing-guides/test-types/)
