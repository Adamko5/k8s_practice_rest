# Kubernetes banking lab

A small Kubernetes project for learning deployment and autoscaling from the terminal.

I'm building a REST API with fictional banking data and running it on a local Kubernetes cluster. The experiment starts with one API Pod on one worker. As traffic grows, Kubernetes adds API replicas on other workers. When traffic drops, it scales back down.

The aim is to understand the commands, configuration files, and decisions behind that behavior. I'll build the lab in stages, inspect what changes, and practice diagnosing failures along the way.

## Project status

Planning stage. The repository currently contains the learning plan and architecture documentation. The API, database setup, Kubernetes manifests, and load tests are still to be implemented.

## The experiment

Three worker nodes are available from the start. A Horizontal Pod Autoscaler (HPA) adjusts the number of API replicas, and placement rules keep those replicas on different workers.

| Traffic | Worker A | Worker B | Worker C |
| --- | --- | --- | --- |
| Low | API replica 1 | Idle API capacity | Idle API capacity |
| Increasing | API replica 1 | API replica 2 | Idle API capacity |
| Sustained high load | API replica 1 | API replica 2 | API replica 3 |

This is the intended progression; the actual timing and replica count will depend on measured CPU usage and the HPA settings. PostgreSQL runs as one persistent database instance and may share a worker with an API Pod.

[kind](https://kind.sigs.k8s.io/docs/user/quick-start/) runs the Kubernetes nodes as Docker containers. They have separate node identities and share the host computer's hardware. The experiment scales Pods across existing nodes; creating new machines automatically is a later topic.

## What I'm learning

- Using `kubectl` to inspect resources, read logs, troubleshoot failures, and manage updates.
- Writing manifests for Deployments, Services, configuration, credentials, and health probes.
- Running PostgreSQL with persistent storage, migration Jobs, and a tested backup and restore.
- Understanding resource requests, limits, and Pod placement across workers.
- Generating load and measuring how CPU-based autoscaling affects throughput, latency, and errors.

The application will use synthetic customers, accounts, balances, and transaction history. The API will include a bounded CPU workload so the first scaling experiment has a clear signal. Database traffic can then help explain when adding API replicas stops improving performance.

## Planned tools

| Part | Initial choice |
| --- | --- |
| Local infrastructure | Docker Desktop with Linux containers, kind |
| Kubernetes workflow | `kubectl`, plain YAML first, Kustomize later |
| REST API | Language and framework to be decided |
| Database | PostgreSQL |
| Load generation | k6 |
| Autoscaling | Metrics Server and Kubernetes HPA |

## Read the project

- [Implementation and learning plan](TODO.md): ordered steps with checks for each concept.
- [Architecture](ARCHITECTURE.md): the planned components and their connections.
- [AI collaboration context](AGENTS.md): goals, scope, and guidance for working on the lab.

Reproduction commands and measured results will be added as the corresponding steps are completed.
