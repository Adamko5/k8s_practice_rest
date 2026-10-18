```mermaid
flowchart TB
    subgraph HOST["One physical computer"]
        OP["Ubuntu WSL workstation<br/>SSH, kubectl, curl, k6"]
        VIRT["VM backend<br/>QEMU/KVM + libvirt candidate"]

        subgraph CLUSTER["Four full Linux VMs on a private network"]
            subgraph CP["bank-lab-cp1 VM"]
                CONTROL["Kubernetes API :6443<br/>Controllers, scheduler, etcd"]
            end

            SERVICE["API Service<br/>Worker VM IP:30080"]
            DEPLOY["API Deployment"]
            HPA["HPA: 1 to 3 replicas"]
            METRICS["Metrics Server"]
            DBSERVICE["PostgreSQL Service<br/>Cluster DNS"]

            subgraph W1["bank-lab-worker1 VM"]
                API1["API replica 1"]
                DB["PostgreSQL Pod"]
                DATA[("PVC on persistent<br/>worker VM disk")]
            end

            subgraph W2["bank-lab-worker2 VM"]
                API2["API replica 2<br/>Under load"]
            end

            subgraph W3["bank-lab-worker3 VM"]
                API3["API replica 3<br/>Under load"]
            end

            CONTROL -.-> DEPLOY
            METRICS -->|CPU metrics| HPA
            HPA --> DEPLOY
            DEPLOY -.-> API1
            DEPLOY -.-> API2
            DEPLOY -.-> API3
            SERVICE --> API1
            SERVICE --> API2
            SERVICE --> API3
            API1 --> DBSERVICE
            API2 --> DBSERVICE
            API3 --> DBSERVICE
            DBSERVICE --> DB
            DB --> DATA
        end

        OP -->|Machine lifecycle| VIRT
        VIRT -.-> CP
        VIRT -.-> W1
        VIRT -.-> W2
        VIRT -.-> W3
        OP -->|kubectl| CONTROL
        OP -->|HTTP| SERVICE
    end
```

Planned architecture at three API replicas. Each VM has its own Linux kernel, disk, virtual NIC, IP address, and SSH access. The owner installs containerd and Kubernetes manually with kubeadm. The VM backend must pass its feasibility check first.

HPA scales the API across three existing workers. PostgreSQL starts as one persistent instance with backups exported outside the guest disks. Local storage stays tied to its worker. All VMs share one physical host; control-plane redundancy and physical host failover are outside this first experiment.
