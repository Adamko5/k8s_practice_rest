# Lesson 02: create the Linux machines

Follow [environment/TODO.md](../../environment/TODO.md) from Ubuntu WSL.

Boot `bank-lab-cp1` first. Check KVM acceleration, SSH, internet access, and disk persistence. Add `bank-lab-worker1` and check traffic between them before creating the remaining workers.

The same VMs become the Kubernetes nodes. Stop if the backend checks fail. Next: [verify all four machines](03-verify-the-linux-machines.md), then Kubernetes installation in [Part 2](../../TODO.md#part-2-manual-kubernetes-installation).
