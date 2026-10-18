# VM setup

Run in `k8s-lab`, in order, except the Windows commands in step 0. Stop on errors. Commands sent through `ssh` run inside that VM.

## 0. Create the dedicated WSL distro

- [ ] Finish any Docker disk compaction and detach its disk before starting WSL.
- [ ] In Windows PowerShell, create a fresh Ubuntu 24.04 distro:

```powershell
New-Item -ItemType Directory -Path 'C:\Me\Dev\WSL' -Force | Out-Null
wsl --install Ubuntu-24.04 --name k8s-lab --location 'C:\Me\Dev\WSL\k8s-lab' --version 2
```

Create the Linux user `lab` with password `lab` when prompted. These are intentional local lab credentials. The Linux disk lives in `C:\Me\Dev\WSL\k8s-lab`; keep personal `Ubuntu` as the default.

- [ ] Inside the new distro, check it and open the repo:

```bash
echo "$WSL_DISTRO_NAME"
whoami
cat /etc/os-release
ps -p 1 -o comm=
cd /mnt/c/Me/Dev/learning/k8s_commands/environment
```

Expect `k8s-lab`, user `lab`, Ubuntu 24.04, and `systemd`. To open this distro again from Windows:

```powershell
wsl -d k8s-lab
```

[Ubuntu installation reference](https://ubuntu.com/wsl/docs/latest/howto/install-ubuntu-wsl2/).

## 1. Check the host

- [ ] Check resources, KVM, and routes.

```bash
free -h
df -h "$HOME" /mnt/c
ps -p 1 -o comm=
ls -l /dev/kvm
ip route show table all
```

Need systemd, `/dev/kvm`, and room for 8 GiB of guest RAM. Check physical free space on `/mnt/c`. VM `192.168.77.0/24`, future Pod `10.244.0.0/16`, and Service `10.96.0.0/12` ranges must not overlap existing LAN, Docker, or VPN networks.

## 2. Install VM tools

- [ ] Install packages and grant VM management access.

```bash
sudo apt-get update
sudo apt-get install -y qemu-system-x86 qemu-utils libvirt-daemon-system \
  libvirt-clients cloud-image-utils gettext-base curl
sudo systemctl enable --now libvirtd.socket
sudo usermod -aG libvirt,kvm "$USER"
```

Open a new `k8s-lab` terminal for group membership to take effect. Use that terminal for the remaining steps.

## 3. Select libvirt and prepare storage

- [ ] Check KVM and create the lab's storage pool.

```bash
cd /mnt/c/Me/Dev/learning/k8s_commands/environment
export LIBVIRT_DEFAULT_URI=qemu:///system
set -a
source config.env
set +a
mkdir -p .state
id
virt-host-validate qemu
virsh list --all
virsh net-list --all
virsh pool-list --all
ls -ld "$POOL" 2>/dev/null || true
```

KVM checks must pass; an IOMMU warning is fine for this lab. Stop if `bank-lab` resources or the pool directory already exist unexpectedly.

```bash
sudo install -d -m 0755 "$POOL"
virsh pool-define-as bank-lab dir --target "$POOL"
virsh pool-start bank-lab
virsh pool-autostart bank-lab
dpkg-query -W qemu-system-x86 qemu-utils libvirt-daemon-system \
  libvirt-clients cloud-image-utils > .state/host-packages.txt
```

## 4. Download the base image

- [ ] Download and verify the pinned Ubuntu image.

```bash
(
  set -e
  if ! sudo test -f "$POOL/ubuntu-base.qcow2"; then
    sudo curl -fL "$IMAGE_URL" -o "$POOL/ubuntu-base.qcow2"
  fi
  printf '%s  %s\n' "$IMAGE_SHA256" "$POOL/ubuntu-base.qcow2" | sudo sha256sum -c -
  sudo chmod 0444 "$POOL/ubuntu-base.qcow2"
)
```

All VM disks will use this read-only base. Keep it while those disks exist. [Pinned checksum source](https://cloud-images.ubuntu.com/releases/noble/release-20260926/SHA256SUMS).

## 5. Configure SSH and the private network

- [ ] Create a dedicated key and start the lab network.

```bash
install -d -m 0700 "$HOME/.ssh"
test -f "$HOME/.ssh/bank-lab" || \
  ssh-keygen -t ed25519 -f "$HOME/.ssh/bank-lab" -N '' -C bank-lab
virsh net-define network.xml
virsh net-start bank-lab
virsh net-autostart bank-lab
virsh net-info bank-lab
```

DHCP reservations give each VM its fixed IP. The private key stays in `~/.ssh/`; guests receive its public key.

## 6. Prepare the VM creation commands

- [ ] Paste this function into the same terminal.

It renders the settings, creates a sparse disk backed by the base image, and boots a plain VM. Cloud-init sets only its hostname and login.

```bash
create_vm() (
  set -euo pipefail
  export VM="$1"
  read -r VM_IP VM_MAC VM_GIB < <(
    awk -v name="$VM" '$1 == name {print $2, $3, $4}' inventory.tsv
  )
  export VM_MAC
  test -s "$HOME/.ssh/bank-lab.pub"
  export SSH_PUBLIC_KEY="$(awk '{print $1 " " $2}' "$HOME/.ssh/bank-lab.pub")"
  if virsh dominfo "$VM" >/dev/null 2>&1; then
    printf 'VM already exists: %s\n' "$VM" >&2
    exit 1
  fi
  sudo test ! -e "$POOL/$VM.qcow2"
  sudo test ! -e "$POOL/$VM-seed.img"
  mkdir -p ".state/$VM"
  envsubst '${VM} ${VM_MAC} ${POOL}' < vm.xml.template > ".state/$VM/vm.xml"
  envsubst '${VM} ${SSH_PUBLIC_KEY}' < user-data.yaml.template > ".state/$VM/user-data"
  printf 'instance-id: %s\nlocal-hostname: %s\n' "$VM" "$VM" > ".state/$VM/meta-data"
  cloud-localds ".state/$VM/seed.img" ".state/$VM/user-data" ".state/$VM/meta-data"
  sudo install -m 0644 ".state/$VM/seed.img" "$POOL/$VM-seed.img"
  sudo qemu-img create -f qcow2 -F qcow2 \
    -b "$POOL/ubuntu-base.qcow2" "$POOL/$VM.qcow2" "${VM_GIB}G"
  sudo chown libvirt-qemu:kvm "$POOL/$VM.qcow2" "$POOL/$VM-seed.img"
  virsh define ".state/$VM/vm.xml"
  virsh start "$VM"
)
```

## 7. Boot and check the first VM

- [ ] Create the future control-plane machine.

```bash
create_vm bank-lab-cp1
virsh qemu-monitor-command bank-lab-cp1 --pretty '{"execute":"query-kvm"}'
virsh net-dhcp-leases bank-lab
```

Require `"enabled": true`. Allow about a minute for the guest to boot, then connect; retry if SSH is not ready yet.

```bash
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.10 \
  'sudo cloud-init status --wait && hostname && uname -r && ps -p 1 -o comm='
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.10 \
  'getent hosts archive.ubuntu.com && sudo apt-get update'
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.10 \
  'cat /etc/machine-id' > .state/cp1-machine-id
```

- [ ] Verify shutdown/start preserves the guest.

```bash
virsh shutdown bank-lab-cp1
virsh domstate bank-lab-cp1
```

Repeat `domstate` until it says `shut off`, then:

```bash
virsh start bank-lab-cp1
```

After SSH is ready:

```bash
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.10 \
  'cat /etc/machine-id' | diff - .state/cp1-machine-id
```

No diff means the machine identity survived. If boot, KVM, SSH, or outbound access fails, resolve it before creating more guests. Console: `virsh console bank-lab-cp1`; leave with `Ctrl+]`.

## 8. Check VM-to-VM networking

- [ ] Create the first worker and check SSH connectivity in both directions.

```bash
create_vm bank-lab-worker1
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.11 'sudo cloud-init status --wait'
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.10 \
  'timeout 5 bash -c "echo > /dev/tcp/192.168.77.11/22"'
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.11 \
  'timeout 5 bash -c "echo > /dev/tcp/192.168.77.10/22"'
```

`/dev/tcp` opens a TCP connection using Bash; no SSH key is copied between VMs.

## 9. Create the remaining workers

- [ ] Boot workers 2 and 3, then inspect all four guests.

```bash
create_vm bank-lab-worker2
create_vm bank-lab-worker3
virsh list --all
while read -r name ip mac disk; do
  ssh -n -i "$HOME/.ssh/bank-lab" "lab@$ip" \
    'sudo cloud-init status --wait && hostname && uname -r && free -h && df -h /'
done < inventory.tsv
```

Retry after boot if SSH is not ready. Continue with the machine checks below; guest OS preparation and containerd follow afterward.

## 10. Check guest identity and time

- [x] From `environment/` inside `k8s-lab`, inspect each guest. Use [start.sh](start.sh) first if the VMs are stopped.

```bash
cd /mnt/c/Me/Dev/learning/k8s_commands/environment
while read -r name ip mac disk; do
  printf '\n--- %s (%s) ---\n' "$name" "$ip"
  ssh -n -i "$HOME/.ssh/bank-lab" "lab@$ip" '
    set -e
    hostname
    printf "Machine ID: "; cat /etc/machine-id
    printf "Hardware UUID: "; sudo cat /sys/class/dmi/id/product_uuid
    ip -brief link
    timedatectl show -p NTP -p NTPSynchronized
    command -v kubeadm kubelet kubectl containerd || true
  '
done < inventory.tsv
```

Hostnames, machine IDs, hardware UUIDs, and non-loopback MAC addresses must differ between guests. Expect `NTP=yes`, `NTPSynchronized=yes`, and no paths for the Kubernetes/runtime commands. Stop if an unexpected tool is already installed. [kubeadm machine requirements](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#verify-the-mac-address-and-product-uuid-are-unique-for-every-node).

`ssh -n` keeps SSH from consuming the inventory loop's input. [timedatectl reference](https://www.freedesktop.org/software/systemd/man/latest/timedatectl.html).

## 11. Check traffic between all four guests

- [x] From the same WSL terminal, test TCP port 22 from every guest to every guest.

```bash
while read -r name ip mac disk; do
  printf '\n--- From %s ---\n' "$name"
  ssh -n -i "$HOME/.ssh/bank-lab" "lab@$ip" '
    for target in 192.168.77.{10..13}; do
      if timeout 3 bash -c "echo > /dev/tcp/$target/22" 2>/dev/null; then
        printf "%s -> %s:22 OK\n" "$(hostname)" "$target"
      else
        printf "%s -> %s:22 FAILED\n" "$(hostname)" "$target" >&2
        exit 1
      fi
    done
  '
done < inventory.tsv
```

Require 16 `OK` results, including each guest's connection to itself. This checks SSH's port; Kubernetes and CNI ports are checked during their installation.

## 12. Check DNS, outbound access, and firewalls

- [x] From the same WSL terminal, inspect each guest's routes, DNS, HTTPS access, and firewall rules.

```bash
while read -r name ip mac disk; do
  printf '\n--- %s ---\n' "$name"
  ssh -n -i "$HOME/.ssh/bank-lab" "lab@$ip" '
    set -e
    ip -brief address
    ip route
    getent ahostsv4 archive.ubuntu.com pkgs.k8s.io
    curl -fsSIL --connect-timeout 5 --max-time 15 --output /dev/null \
      https://archive.ubuntu.com/ubuntu/dists/noble/InRelease
    printf "Ubuntu archive HTTPS: OK\n"
    sudo ufw status verbose
    sudo nft list ruleset
  '
done < inventory.tsv
```

Expect the inventory IP on each guest, default route via `192.168.77.1`, resolved DNS names, and four HTTPS `OK` results. Review any active firewall rules before continuing; this step changes none. The control-plane API will use `192.168.77.10:6443` after kubeadm initialization.

The owner reported steps 10–12 completed successfully. Kubernetes/CNI port checks follow installation of those components.

## 13. Copy the guest OS settings

- [ ] Inside `k8s-lab`, from `environment/`, copy the two settings files to the existing guests. Start the VMs first if needed.

```bash
cd /mnt/c/Me/Dev/learning/k8s_commands/environment
(
  set -e
  while read -r name ip mac disk; do
    scp -B -i "$HOME/.ssh/bank-lab" \
      nodes/bank-lab-modules.conf nodes/bank-lab-sysctl.conf \
      "lab@$ip:/tmp/" < /dev/null
  done < inventory.tsv
)
```

Open the first guest from WSL:

```bash
NODE_IP=192.168.77.10
ssh -i "$HOME/.ssh/bank-lab" "lab@$NODE_IP"
```

Follow steps 14–18 for this VM. Guest commands run **inside the VM**; reconnect commands run in WSL. Finish it, then set `NODE_IP` in WSL to `192.168.77.11`, `.12`, and `.13` in turn and repeat. The SSH prompt must show the guest's name, such as `lab@bank-lab-cp1`.

## 14. Keep guest swap disabled

- [ ] Inside the guest, disable any active swap and inspect its boot configuration.

```bash
hostname
sudo swapoff -a
swapon --show
findmnt --fstab --types swap || true
systemctl list-units --all --type=swap --no-pager
```

Expect no swap rows or configured swap units with this image. If any are configured, resolve their boot configuration before continuing; `swapoff` affects only the current boot. This lab uses swap disabled with kubelet's default policy.

## 15. Load the guest kernel modules

- [ ] Inside the guest, install [the module list](nodes/bank-lab-modules.conf) for boot and load the modules now.

```bash
sudo install -m 0644 /tmp/bank-lab-modules.conf /etc/modules-load.d/99-bank-lab-k8s.conf
sudo modprobe overlay
sudo modprobe br_netfilter
lsmod | grep -E '^(overlay|br_netfilter)[[:space:]]'
```

`overlay` supplies container filesystem layers. `br_netfilter` exposes bridged traffic to netfilter and is required by the selected Flannel network. `modprobe` changes the running kernel; `modules-load.d` makes the selection persist across boots.

## 16. Enable guest packet forwarding and bridge filtering

- [ ] Inside the guest, install and apply [the IPv4 settings](nodes/bank-lab-sysctl.conf).

```bash
sudo install -m 0644 /tmp/bank-lab-sysctl.conf /etc/sysctl.d/99-bank-lab-k8s.conf
sudo sysctl -p /etc/sysctl.d/99-bank-lab-k8s.conf
rm -- /tmp/bank-lab-modules.conf /tmp/bank-lab-sysctl.conf
```

Both values must be `1`. `ip_forward` permits routing between interfaces; `bridge-nf-call-iptables` sends bridged IPv4 traffic through netfilter's IPv4 rules. The file persists these settings; `sysctl -p` applies them now. Firewall rules stay as inspected in step 12.

## 17. Check guest systemd and cgroups

- [ ] Inside the guest, check how services and resource groups are managed.

```bash
ps -p 1 -o comm=
stat -fc %T /sys/fs/cgroup
```

Expect `systemd` and `cgroup2fs`. Containerd and kubelet will use the `systemd` cgroup driver when installed.

## 18. Reboot and verify persistence

- [ ] Inside the guest, note its boot ID and reboot it.

```bash
cat /proc/sys/kernel/random/boot_id
sudo reboot
```

SSH disconnects. From WSL, reconnect after the guest boots; retry if SSH is not ready:

```bash
ssh -i "$HOME/.ssh/bank-lab" "lab@$NODE_IP"
```

`NODE_IP` remains set in the WSL terminal while SSH is running. Inside the rebooted guest:

```bash
hostname
cat /proc/sys/kernel/random/boot_id
swapon --show
lsmod | grep -E '^(overlay|br_netfilter)[[:space:]]'
sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
systemctl --failed --no-pager
```

Require a changed boot ID, no active swap, both modules, both sysctl values `1`, `cgroup2fs`, and no failed units. Return to WSL with `exit`, then repeat steps 14–18 on the next guest. All four must pass before containerd installation.

References: [kubeadm swap policy](https://v1-36.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#swap-configuration), [Kubernetes IPv4 forwarding](https://v1-36.docs.kubernetes.io/docs/setup/production-environment/container-runtimes/#enable-ipv4-packet-forwarding), [Flannel prerequisites](https://github.com/flannel-io/flannel#deploying-flannel-manually), [systemd boot-time sysctls](https://www.freedesktop.org/software/systemd/man/latest/sysctl.d.html).

## Daily commands

Start the existing VMs inside `k8s-lab`:

```bash
cd /mnt/c/Me/Dev/learning/k8s_commands/environment
bash start.sh
```

Startup activates the lab network/pool, boots the control plane first, and checks SSH on all four VMs using the existing lab key and known host keys. SSH availability does not mean Kubernetes is ready.

Stop them from the same directory:

```bash
bash stop.sh
```

Shutdown waits for the workers, then the control plane, then terminates `k8s-lab` and closes its terminal. Other WSL distros and Docker Desktop are left alone. Both scripts use `qemu:///system`, preserve disks, and skip VMs already in the requested state. Each VM wait defaults to 120 seconds; shutdown stops on failure without forcing power off or terminating WSL.

To stop only the VMs and keep the lab terminal open:

```bash
bash stop.sh --keep-wsl
```

Reopen `k8s-lab` from Windows, then run `bash start.sh` again:

```powershell
wsl -d k8s-lab
```

For individual VM operations inside `k8s-lab`:

```bash
export LIBVIRT_DEFAULT_URI=qemu:///system
virsh list --all
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.11
virsh shutdown bank-lab-worker1
virsh start bank-lab-worker1
virsh reboot bank-lab-worker1
```

Individual shutdown is asynchronous. Guest autostart is left disabled. Kubernetes maintenance commands follow cluster installation.

References: [Ubuntu libvirt](https://ubuntu.com/server/docs/how-to/virtualisation/libvirt/), [libvirt network settings](https://libvirt.org/formatnetwork.html).
