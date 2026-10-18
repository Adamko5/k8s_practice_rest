# Lesson 08: kubeconfig and debugging

Setup commands: [environment/TODO.md, steps 36–38](../../environment/TODO.md#36-configure-the-wsl-operator-context). Access is configured and verified in WSL and as user `lab` on `bank-lab-cp1`.

In your WSL terminal, or inside cp1:

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

The selected context is `bank-lab`. Kubectl reads `~/.kube/config` automatically: it contains the API address, CA trust, and your authentication credentials. A context selects a cluster, user, and namespace. This is client access configuration; `kubeadm-init.yaml` is the separate bootstrap input.

The first control-plane checks explicitly selected `/etc/kubernetes/admin.conf` because no user kubeconfig existed. Normal commands now run as `lab`, without sudo or extra flags. Use `--context bank-lab` explicitly in automation and commands that change resources. This lab uses bootstrap administrator credentials; company access may use your own login and narrower RBAC permissions.

Use WSL for normal administration. Requests go over the VM network to `192.168.77.10:6443`; you do not need to SSH in for kubectl. The cp1 copy provides the same access when working inside that guest.

If the API is unavailable, kubectl cannot manage the cluster. SSH into the affected VM and inspect its services and containers:

```bash
sudo systemctl status kubelet containerd --no-pager
sudo journalctl -u kubelet -n 40 --no-pager
sudo crictl ps -a
```

Disaster-recovery exercises come later. Kubeconfig is not a cluster backup: control-plane recovery needs etcd state and the appropriate PKI/configuration backups; PostgreSQL data needs its own tested backup and restore. No recovery drill or backup setup was performed here.
