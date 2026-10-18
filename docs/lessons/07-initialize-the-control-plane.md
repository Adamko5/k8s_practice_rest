# Lesson 07: initialize the control plane

Reproduction commands: [environment/TODO.md, steps 30–35](../../environment/TODO.md#30-align-the-runtime-sandbox-image). Configuration: [kubeadm-init.yaml](../../environment/kubernetes/kubeadm-init.yaml). The owner completed initialization on 2026-10-18. The agent verified a ready API, four running control-plane static Pods, and the expected NotReady node before CNI installation.

First align containerd's sandbox image with kubeadm's expected `pause:3.10.2`. Then run `kubeadm init` on **bank-lab-cp1 only**.

The YAML has three sections:

- `InitConfiguration`: this VM's name, private address, and containerd socket.
- `ClusterConfiguration`: Kubernetes version, API endpoint, certificate addresses, and Pod/Service networks. These ranges are separate from the VMs' `192.168.77.0/24` network.
- `KubeletConfiguration`: systemd cgroups and the requirement for swap to remain off.

The `certSANs` entries allow TLS certificate validation for those addresses; they do not create DNS records. Kubeadm reads this YAML directly, without loading `config.env` or substituting environment variables.

Init creates certificates, access files, and four static Pod manifests: API server, scheduler, controller manager, and etcd. Kubelet watches `/etc/kubernetes/manifests/` and starts those Pods through containerd. They use the VM's network, so the API can work before Pod networking exists.

After successful init, expect one registered node, `bank-lab-cp1`, marked `NotReady` until CNI installation. CoreDNS can remain `Pending`; the three workers have not joined. Keep the control-plane scheduling taint. The initial checks use the generated admin kubeconfig explicitly. [Lesson 08](08-kubeconfig-and-debugging.md) sets up ordinary kubectl access in WSL and inside cp1.

Stop after inspection. Flannel installation and worker joins are separate steps. If init fails, keep the output and existing VM state for troubleshooting.
