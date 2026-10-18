# Lesson 04: prepare Linux for Kubernetes

Follow [environment/TODO.md, steps 13–18](../../environment/TODO.md#13-copy-the-guest-os-settings).

Keep swap disabled, load the container storage and bridge-filter modules, enable IPv4 forwarding and bridge filtering, then verify the settings after a reboot. Apply the changes over SSH to one guest at a time.

Settings: [kernel modules](../../environment/nodes/bank-lab-modules.conf) and [network sysctls](../../environment/nodes/bank-lab-sysctl.conf). The WSL host keeps its existing configuration. Containerd installation is the next lesson.
