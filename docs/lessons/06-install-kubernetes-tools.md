# Lesson 06: install Kubernetes tools

Reproduction commands: [environment/TODO.md, steps 25–29](../../environment/TODO.md#25-copy-the-kubernetes-package-settings). Settings: [package pins](../../environment/kubernetes/versions.env) and [APT repository](../../environment/kubernetes/kubernetes.list).

Completed and verified on all four VMs and the WSL operator on 2026-10-18. Cluster bootstrap remains the next step.

- **kubeadm** creates the control plane with `init` and adds nodes with `join`.
- **kubelet** is the service on each node that asks containerd to run Pods and reports their status.
- **kubectl** sends your commands to the Kubernetes API. It is also installed on the WSL operator.

The selected version is `v1.36.5`. APT verifies packages using the repository signing key; package holds prevent accidental upgrades. The package-managed crictl replaces Lesson 05's manual binary and keeps `/etc/crictl.yaml`. The `kubernetes-cni` package provides network helper binaries; Flannel and Pod networking still need configuration.

From WSL, inspect the client or connect to the control-plane VM:

```bash
kubectl version --client
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.10
```

Inside `bank-lab-cp1`:

```bash
kubeadm version -o short               # Bootstrap tool version
kubelet --version                     # Node agent version
systemctl cat kubelet                 # Service definition and kubeadm arguments
systemctl is-enabled kubelet           # Enabled for future boots
systemctl show kubelet -p ActiveState  # Intentionally inactive before bootstrap
```

At this checkpoint, kubelet is enabled but stopped until `kubeadm init` or `join` writes its configuration and starts it. Rebooting a guest before bootstrap can make kubelet report the missing configuration. Later lessons initialize cp1 and configure kubectl access. Use `exit` to return to WSL.
