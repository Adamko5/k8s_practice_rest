# Lesson 02: create the Kubernetes cluster

Goal: create one control-plane node and three workers with kind, then inspect the machines from Docker and Kubernetes. This prepares the infrastructure for the API and database; application deployment and autoscaling come in later lessons.

Step 01 is complete. Run all commands below from your Ubuntu terminal, in this repository. This guide has been prepared for you to follow; the cluster has not been created by writing it.

## 1. Locate the project and check for an existing lab

```bash
cd /mnt/c/Me/Dev/learning/k8s_commands
docker context show
kind get clusters
```

Use the Docker engine connected during Lesson 01. If `bank-lab` already appears, inspect that cluster before deciding whether to reuse or recreate it. Do not automatically delete an existing lab to rerun this lesson.

Ubuntu is your personal workstation. The cluster runs in Docker Desktop's engine; you do not need another Docker daemon, an SSH server, or a Kubernetes installation directly on Ubuntu.

## 2. Write the cluster configuration

Create the project directory:

```bash
mkdir -p cluster
```

Create `cluster/kind.yaml` in your editor with the following content. If the file already exists, compare it before changing it.

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    image: kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed
    extraPortMappings:
      - containerPort: 30080
        hostPort: 8080
        listenAddress: "127.0.0.1"
        protocol: TCP
  - role: worker
    image: kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed
  - role: worker
    image: kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed
  - role: worker
    image: kindest/node:v1.36.4@sha256:099e049362a1526b2db71494e1947aae99bd16290d7c895f2b7ea312e3cbfaed
```

This is input for kind. Its `kind: Cluster` and `apiVersion` describe kind's configuration format; this file is not a workload manifest to apply with `kubectl`.

### Node topology

Each entry under `nodes` creates one Docker container acting as a Kubernetes node. The control-plane node hosts the API server and management components. The three workers provide places for our application Pods to run.

All four containers share the same host's hardware. A worker is not a separately purchased machine, and adding one does not add physical RAM or CPU capacity.

### Kubernetes image

Every node uses the same Kubernetes 1.36.4 image from the kind 0.33.0 release. This keeps the server on the same minor version as the installed kubectl 1.36.1. The `sha256` digest fixes the image contents for reproducibility. The image contains node software; it is different from the API container image we will build later.

### Entry port for the future API

| Setting | Purpose |
| --- | --- |
| `hostPort: 8080` | Reserves the local entry port for the future API |
| `containerPort: 30080` | Forwards it to port 30080 on this kind node container |
| `listenAddress: "127.0.0.1"` | Binds the published port to loopback |
| `protocol: TCP` | Uses TCP for the mapping |

Later, the API's NodePort Service will use `nodePort: 30080`, matching the node-container port. The mapping is on the control-plane container, but Service traffic can reach API Pods on workers. It does not place the API on the control plane.

There is no API or NodePort Service yet, so an HTTP response on port 8080 is not a success condition for this lesson. We reserve the mapping now because changing kind node settings generally means recreating the cluster.

## 3. Know what creation will add

| Artifact | Location and lifecycle |
| --- | --- |
| `cluster/kind.yaml` | Your versioned cluster definition in this repository |
| `cluster/bank-lab.kubeconfig` | Generated local cluster access file, ignored by Git |
| Four node containers | Docker Desktop engine, named with the `bank-lab` prefix |
| Node image and node data | Docker-managed storage; the image can remain cached after teardown |
| Docker network | kind creates or reuses its `kind` network, which can be shared by other kind clusters |

The kubeconfig file records how to contact this cluster and authenticate to it. We give kind an explicit project-local path so this lesson does not merge lab entries into your personal `~/.kube/config`. There is no need to edit shell startup files or persist a `KUBECONFIG` environment variable.

## 4. Create the cluster

```bash
KIND_EXPERIMENTAL_PROVIDER=docker kind create cluster \
  --name bank-lab \
  --config cluster/kind.yaml \
  --kubeconfig cluster/bank-lab.kubeconfig \
  --wait 120s
```

The environment assignment chooses Docker for this command only. `--name` identifies the lab, `--config` supplies the topology, and `--kubeconfig` selects the generated access file. The trailing `\` characters continue one Bash command onto the next line.

kind downloads the node image if needed, creates the node containers, initializes Kubernetes, and joins the workers. `--wait 120s` waits up to two minutes for control-plane readiness after the earlier setup stages; it is not a two-minute limit on the entire download and creation process. We check all nodes next.

If creation reports that port 8080 is occupied, identify the existing listener or container before changing the lab's mapping. Do not stop an unrelated service to free it. If another error occurs, keep the error output and inspect the state before retrying or cleaning anything up.

## 5. Inspect the result from Docker

```bash
kind get clusters

docker ps \
  --filter label=io.x-k8s.kind.cluster=bank-lab \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
```

Expect four named node containers:

| Container | Role |
| --- | --- |
| `bank-lab-control-plane` | Control plane |
| `bank-lab-worker` | Worker |
| `bank-lab-worker2` | Worker |
| `bank-lab-worker3` | Worker |

The control-plane container should show the published 8080-to-30080 mapping. It will also have a separately published Kubernetes API port; that management port is not the future API application's port.

Inspect the Docker network and node addresses:

```bash
docker network inspect kind --format '{{range .Containers}}{{println .Name .IPv4Address}}{{end}}'
```

Look for all four lab nodes and their addresses. Other kind clusters can appear on this shared network too. Addresses may change on recreation; do not use them as permanent application settings. Docker Desktop networking also means they are not necessarily directly reachable from Ubuntu just because inspection shows an IP.

## 6. Inspect the result from Kubernetes

```bash
kubectl --kubeconfig cluster/bank-lab.kubeconfig config current-context

kubectl --kubeconfig cluster/bank-lab.kubeconfig \
  wait --for=condition=Ready nodes --all --timeout=120s

kubectl --kubeconfig cluster/bank-lab.kubeconfig get nodes -o wide
```

Expect context `kind-bank-lab` and four Ready nodes using Kubernetes 1.36.4. Worker nodes may show `<none>` in the `ROLES` column; that does not mean they failed to join. Compare their internal addresses with the Docker network output.

Docker shows the containers acting as machines. Kubernetes shows those machines registered as nodes. A Pod is the unit Kubernetes schedules onto one node; there are no banking application Pods yet. Kubernetes already has its own system workloads.

Lesson 03 will examine kubeconfig, contexts, node details, and system components more closely. This lesson only uses them to verify creation.

## 7. Optional: inspect a node's Linux environment

From the Ubuntu workstation terminal:

```bash
docker exec -it bank-lab-worker bash
```

Inside the node container:

```bash
hostname
cat /etc/os-release
exit
```

You are inspecting another container's environment. Its operating-system release can differ from Ubuntu's. `exit` returns to the workstation terminal. This is process execution through Docker, not SSH; no SSH service is needed. Keep the inspection read-only so your reproducible setup stays in the configuration file.

Application containers on these nodes are managed by the node's container runtime. They are distinct from the Docker node container into which you just opened a shell.

## 8. Record the result

Before marking Step 02 complete, check:

- [ ] `cluster/kind.yaml` contains one control-plane node and three workers.
- [ ] Docker shows four running lab node containers and the expected port mapping.
- [ ] The Docker network contains their separate node addresses.
- [ ] Kubernetes reports four Ready nodes on version 1.36.4.
- [ ] The project-local kubeconfig works without adding lab entries to personal cluster configuration.
- [ ] You can explain the difference between Docker node containers, Kubernetes nodes, and application Pods.

Record any actual output or error worth keeping in your lesson notes. The tables above describe expected results, not a claim that creation has already succeeded.

## Optional teardown, when you are finished with the lab

Keep the cluster for Lesson 03. Closing a terminal does not stop its containers.

When you deliberately want to remove this lab:

```bash
kind delete cluster \
  --name bank-lab \
  --kubeconfig cluster/bank-lab.kubeconfig
```

This removes the named lab's node containers and their stored node state, and updates the specified kubeconfig. Once database storage exists, teardown can remove that data too; preserve anything needed before deleting the cluster. The versioned configuration remains available to recreate it.

Cached images and the shared `kind` network may remain. They are managed Docker artifacts and can be useful for recreation or other clusters. Do not remove the shared network or use broad Docker pruning as part of this lesson.

## References

- [kind cluster configuration](https://kind.sigs.k8s.io/docs/user/configuration/)
- [kind creation and kubeconfig options](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kind 0.33.0 release and Kubernetes 1.36.4 image digest](https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0)
- [kind on WSL 2](https://kind.sigs.k8s.io/docs/user/using-wsl2/)
