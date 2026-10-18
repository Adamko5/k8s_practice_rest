```mermaid
flowchart TB
    subgraph HOST["Local computer"]
        CLIENT["WSL Linux terminal<br/>curl / k6"]
        PORT["localhost:8080<br/>Docker port mapping"]

        subgraph CLUSTER["kind cluster: Docker containers on one network"]
            CONTROL["Control-plane node<br/>Kubernetes API and controllers"]
            DEPLOY["API Deployment"]
            HPA["HPA: 1 to 3 API replicas"]
            METRICS["Metrics Server<br/>CPU metrics from kubelets"]
            SERVICE["bank-api Service<br/>NodePort 30080"]
            DBSERVICE["postgres Service<br/>Internal database address"]

            subgraph A["Worker A"]
                API1["API replica 1"]
                DB["PostgreSQL<br/>1 Pod in a StatefulSet"]
                DATA[("Database PVC<br/>Local persistent volume")]
            end

            subgraph B["Worker B"]
                API2["API replica 2<br/>Added under load"]
            end

            subgraph C["Worker C"]
                API3["API replica 3<br/>Added under load"]
            end

            CONTROL -.-> DEPLOY
            METRICS -->|CPU metrics| HPA
            HPA -->|Updates desired replicas| DEPLOY
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

        CLIENT --> PORT
        PORT --> SERVICE
    end
```

Planned architecture, shown at three API replicas. kind provides one control-plane node and three workers. A Service routes requests to ready API Pods, and every replica connects to the same PostgreSQL database containing fictional banking data.

HPA adjusts the Deployment from one to three replicas using CPU metrics. Required Pod anti-affinity keeps API replicas on different workers. The workers already exist before scaling begins.

All nodes share one computer. The database volume survives Pod recreation but remains tied to its storage node; portable storage and database failover are later exercises. Backups will be exported outside the cluster.
