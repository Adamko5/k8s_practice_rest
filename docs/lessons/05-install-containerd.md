# Lesson 05: install containerd

Follow [environment/TODO.md, steps 19–24](../../environment/TODO.md#19-copy-the-containerd-settings).

Completed on all four VMs on 2026-10-18, including image pulls and verification after reboot. This stage prepares the container runtime; cluster bootstrap is separate.

Containerd manages container images and running containers. It uses runc to create isolated Linux processes. Kubernetes' node agent, kubelet, will ask containerd to run containers through the Container Runtime Interface (CRI). The crictl command lets you inspect that interface directly.

The configuration enables CRI, uses OverlayFS for container filesystems, and uses systemd cgroups to manage CPU and memory. Containerd starts automatically when the VM boots. Package versions are pinned and held so upgrades are deliberate.

Files: [version pins](../../environment/runtime/versions.env), [containerd configuration](../../environment/runtime/containerd.toml), and [crictl endpoints](../../environment/runtime/crictl.yaml). Continue with [Lesson 06: Kubernetes tools](06-install-kubernetes-tools.md).

From the WSL operator terminal, connect to worker 1:

```bash
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.11
```

Inside `bank-lab-worker1`, try:

```bash
systemctl status containerd --no-pager # Service and its process
sudo crictl version                  # Runtime and CRI versions
sudo crictl images                   # Downloaded images
sudo crictl ps -a                    # Containers, including stopped ones
sudo crictl info                     # Runtime readiness and configuration
```

Expect a cached `pause` image and no containers yet. `RuntimeReady` should be true; `NetworkReady` remains false until we install Pod networking. An image in the cache is not a running container. Use `exit` to return to WSL.
