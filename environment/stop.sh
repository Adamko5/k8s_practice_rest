#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

CONTROL_PLANE=bank-lab-cp1
WORKERS=(bank-lab-worker1 bank-lab-worker2 bank-lab-worker3)
NODES=("${WORKERS[@]}" "$CONTROL_PLANE")
WAIT_SECONDS=${LAB_WAIT_SECONDS:-120}
STOP_WSL=true

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
virsh_lab() { virsh --connect qemu:///system "$@"; }

[[ $# -le 1 ]] || fail 'Usage: bash stop.sh [--keep-wsl]'
case ${1:-} in
  ''|--wsl) ;;
  --keep-wsl) STOP_WSL=false ;;
  *) fail 'Usage: bash stop.sh [--keep-wsl]' ;;
esac
[[ -z ${WSL_DISTRO_NAME:-} || $WSL_DISTRO_NAME == k8s-lab ]] || fail 'Run inside k8s-lab.'
[[ $WAIT_SECONDS =~ ^[1-9][0-9]*$ ]] || fail 'LAB_WAIT_SECONDS must be a positive integer.'
command -v virsh >/dev/null || fail 'Install the VM tools from environment/TODO.md first.'
if "$STOP_WSL"; then
  [[ ${WSL_DISTRO_NAME:-} == k8s-lab ]] || fail 'Default shutdown requires k8s-lab. Use --keep-wsl for VM-only shutdown.'
  command -v wsl.exe >/dev/null || fail 'wsl.exe is unavailable; use --keep-wsl, then terminate k8s-lab from PowerShell.'
fi

# Check all four machines before requesting any shutdowns.
for node in "${NODES[@]}"; do
  case $(virsh_lab domstate "$node") in
    running|'in shutdown'|'shut off') ;;
    *) fail "$node has an unexpected state. Check virsh domstate."
      ;;
  esac
done

shutdown_vm() {
  local node=$1
  case $(virsh_lab domstate "$node") in
    running) virsh_lab shutdown "$node" ;;
    'in shutdown') printf '%s is already shutting down.\n' "$node" ;;
    'shut off') printf '%s is already shut off.\n' "$node" ;;
    *) fail "Cannot shut down $node in its current state." ;;
  esac
}

wait_until_stopped() {
  local node=$1 deadline=$((SECONDS + WAIT_SECONDS))
  until [[ $(virsh_lab domstate "$node") == 'shut off' ]]; do
    (( SECONDS < deadline )) || fail "$node did not shut down within ${WAIT_SECONDS}s; no forced shutdown or WSL termination was performed."
    sleep 1
  done
}

for node in "${WORKERS[@]}"; do
  shutdown_vm "$node"
done
for node in "${WORKERS[@]}"; do
  wait_until_stopped "$node"
done
shutdown_vm "$CONTROL_PLANE"
wait_until_stopped "$CONTROL_PLANE"

printf 'All lab VMs are shut off. Disks are preserved.\n'
if "$STOP_WSL"; then
  printf 'Stopping k8s-lab; this terminal session will close.\n'
  exec wsl.exe --terminate k8s-lab
fi
