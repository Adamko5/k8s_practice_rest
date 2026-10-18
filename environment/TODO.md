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

Retry after boot if SSH is not ready. Next: guest OS prerequisites, containerd, and manual kubeadm setup in [the learning plan](../TODO.md#part-2-manual-kubernetes-installation).

## Daily commands

WSL, with `export LIBVIRT_DEFAULT_URI=qemu:///system` in the current terminal:

```bash
virsh list --all
ssh -i "$HOME/.ssh/bank-lab" lab@192.168.77.11
virsh shutdown bank-lab-worker1
virsh start bank-lab-worker1
virsh reboot bank-lab-worker1
```

Shutdown is asynchronous. These commands preserve disks. Start the control plane first; shut it down last. Guest autostart is left disabled. Kubernetes maintenance commands follow cluster installation.

References: [Ubuntu libvirt](https://ubuntu.com/server/docs/how-to/virtualisation/libvirt/), [libvirt network settings](https://libvirt.org/formatnetwork.html).
