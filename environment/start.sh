#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONTROL_PLANE=bank-lab-cp1
WORKERS=(bank-lab-worker1 bank-lab-worker2 bank-lab-worker3)
NODES=("$CONTROL_PLANE" "${WORKERS[@]}")
WAIT_SECONDS=${LAB_WAIT_SECONDS:-120}
SSH_KEY="$HOME/.ssh/bank-lab"

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
virsh_lab() { virsh --connect qemu:///system "$@"; }

[[ $# -eq 0 ]] || fail 'Usage: bash start.sh'
[[ -z ${WSL_DISTRO_NAME:-} || $WSL_DISTRO_NAME == k8s-lab ]] || fail 'Run inside k8s-lab.'
[[ $WAIT_SECONDS =~ ^[1-9][0-9]*$ ]] || fail 'LAB_WAIT_SECONDS must be a positive integer.'
command -v virsh >/dev/null || fail 'Install the VM tools from environment/TODO.md first.'
[[ -r $SSH_KEY ]] || fail "SSH key not found: $SSH_KEY"

# Check all four existing machines before changing anything.
declare -A IPS
for node in "${NODES[@]}"; do
  virsh_lab dominfo "$node" >/dev/null
  IPS[$node]=$(awk -v name="$node" '$1 == name {print $2}' "$SCRIPT_DIR/inventory.tsv")
  [[ -n ${IPS[$node]} && ${IPS[$node]} != *$'\n'* ]] || fail "Expected one inventory address for $node."
  case $(virsh_lab domstate "$node") in
    running) ;;
    'shut off')
      [[ -r /dev/kvm && -w /dev/kvm ]] || fail 'KVM access denied; check /dev/kvm ownership and kvm group membership.'
      ;;
    *) fail "$node must be running or shut off. Check virsh domstate."
      ;;
  esac
done

if [[ $(virsh_lab net-info bank-lab | awk '$1 == "Active:" {print $2}') != yes ]]; then
  virsh_lab net-start bank-lab
fi
if [[ $(virsh_lab pool-info bank-lab | awk '$1 == "State:" {print $2}') != running ]]; then
  virsh_lab pool-start bank-lab
fi

start_vm() {
  local node=$1
  if [[ $(virsh_lab domstate "$node") == 'shut off' ]]; then
    virsh_lab start "$node"
  else
    printf '%s is already running.\n' "$node"
  fi
}

wait_for_ssh() {
  local node=$1 deadline=$((SECONDS + WAIT_SECONDS))
  printf 'Waiting for SSH on %s...\n' "$node"
  until timeout 5 ssh -n -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=3 \
    -o ConnectionAttempts=1 -o StrictHostKeyChecking=yes \
    "lab@${IPS[$node]}" true >/dev/null 2>&1; do
    (( SECONDS < deadline )) || fail "SSH did not become available on $node within ${WAIT_SECONDS}s. Check it manually."
    sleep 1
  done
  printf '%s is reachable over SSH.\n' "$node"
}

start_vm "$CONTROL_PLANE"
wait_for_ssh "$CONTROL_PLANE"
for node in "${WORKERS[@]}"; do
  start_vm "$node"
done
for node in "${WORKERS[@]}"; do
  wait_for_ssh "$node"
done

printf 'All lab VMs are running and reachable over SSH.\n'
