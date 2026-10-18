# Lesson 03: verify the Linux machines

Follow [environment/TODO.md, steps 10–12](../../environment/TODO.md#10-check-guest-identity-and-time). Start the lab first if it is stopped.

Check unique machine identities, clock synchronization, traffic between all four VMs, outbound DNS/HTTPS, and current firewall rules. Commands run from `k8s-lab`; the commands inside `ssh` run on the guests.

These are inspection commands. Next: [prepare Linux for Kubernetes](04-prepare-linux-for-kubernetes.md), followed by containerd installation.
