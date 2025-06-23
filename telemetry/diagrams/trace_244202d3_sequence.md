# Trace Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    participant Client
    participant System
    Client->>System: coordination_helper.main
    System->>System: coordination_helper.main → work.status
```
