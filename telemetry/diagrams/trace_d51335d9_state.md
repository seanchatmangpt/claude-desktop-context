# Trace State Diagram

```mermaid
stateDiagram-v2
    [*] --> Initiated
    Initiated --> COORDINATION_HELPER: coordination_helper.main
    COORDINATION_HELPER --> WORK: work.claim
    Initiated --> [*]
```
