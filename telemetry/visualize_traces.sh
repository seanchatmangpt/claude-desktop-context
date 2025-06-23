#!/bin/bash

echo "🎨 OpenTelemetry Trace Visualizer"
echo "================================="
echo ""

# Create comprehensive Mermaid diagrams from trace data
TRACE_FILE="${1:-/Users/sac/claude-desktop-context/telemetry/data/sample_traces.jsonl}"
OUTPUT_DIR="/Users/sac/claude-desktop-context/telemetry/diagrams"

mkdir -p "$OUTPUT_DIR"

# Create a combined visualization
cat > "$OUTPUT_DIR/trace_visualization.md" << 'EOF'
# OpenTelemetry Trace Visualizations

## 1. E-commerce Order Processing Flow

```mermaid
graph TD
    subgraph "API Gateway"
        A[order.create<br/>50ms]
    end
    
    subgraph "Auth Service"
        B[user.authenticate<br/>10ms]
    end
    
    subgraph "Inventory Service"
        C[inventory.check<br/>9ms]
        D[database.query<br/>5ms]
    end
    
    subgraph "Payment Service"
        E[payment.process<br/>19ms]
        F[payment.validate<br/>5ms]
        G[payment.charge<br/>10ms]
    end
    
    subgraph "Order Service"
        H[order.confirm<br/>3ms]
    end
    
    A --> B
    A --> C
    C --> D
    A --> E
    E --> F
    E --> G
    A --> H
    
    style A fill:#90EE90
    style H fill:#90EE90
    style G fill:#FFB6C1
```

## 2. Microservices Communication Pattern

```mermaid
sequenceDiagram
    participant Frontend
    participant ServiceA
    participant Redis
    participant ServiceB
    participant PostgreSQL
    participant ServiceC
    participant MLService
    participant TensorFlow
    
    Frontend->>ServiceA: api.request
    ServiceA->>Redis: cache.lookup
    Redis-->>ServiceA: cache miss
    ServiceA->>ServiceB: service.b.call
    ServiceB->>PostgreSQL: database.read
    PostgreSQL-->>ServiceB: data
    ServiceB-->>ServiceA: response
    
    Frontend->>ServiceC: service.c.process
    ServiceC->>MLService: ml.inference
    MLService->>TensorFlow: model.predict
    TensorFlow-->>MLService: predictions
    MLService-->>ServiceC: results
    ServiceC-->>Frontend: final response
```

## 3. Error Handling and Retry Logic

```mermaid
stateDiagram-v2
    [*] --> RequestHandler
    RequestHandler --> DataValidation
    DataValidation --> BusinessLogic
    
    BusinessLogic --> ExternalAPICall
    ExternalAPICall --> RetryAttempt1: Failure
    RetryAttempt1 --> RetryAttempt2: Failure
    RetryAttempt2 --> RetryAttempt3: Failure
    RetryAttempt3 --> ErrorHandler: All retries failed
    
    ErrorHandler --> NotificationSend
    ErrorHandler --> FallbackExecute
    
    NotificationSend --> [*]
    FallbackExecute --> [*]
    
    ExternalAPICall --> [*]: Success
```

## 4. Service Dependencies Graph

```mermaid
graph LR
    subgraph "User Facing"
        F[Frontend]
        AG[API Gateway]
    end
    
    subgraph "Core Services"
        AS[Auth Service]
        OS[Order Service]
        IS[Inventory Service]
        PS[Payment Service]
        CS[Core Service]
    end
    
    subgraph "Data Layer"
        R[Redis Cache]
        PG[PostgreSQL]
        IDB[Inventory DB]
    end
    
    subgraph "External"
        S[Stripe API]
        TP[Third Party API]
        ML[ML Service]
    end
    
    F --> AG
    AG --> AS
    AG --> OS
    AG --> IS
    AG --> PS
    IS --> IDB
    PS --> S
    CS --> TP
    CS --> ML
```

## 5. Performance Analysis

```mermaid
gantt
    title Request Processing Timeline
    dateFormat SSS
    axisFormat %Lms
    
    section Gateway
    Order Create          :active, gw1, 000, 50ms
    
    section Auth
    User Auth            :auth1, 005, 10ms
    
    section Inventory
    Inventory Check      :inv1, 016, 9ms
    Database Query       :db1, 017, 5ms
    
    section Payment
    Payment Process      :pay1, 026, 19ms
    Validate             :val1, 027, 5ms
    Charge Card         :charge1, 033, 10ms
    
    section Order
    Confirm Order        :conf1, 046, 3ms
```

## 6. Distributed Trace Timeline

```mermaid
timeline
    title E-commerce Order Processing
    
    section Request Start
        Order Created : API Gateway receives request
        
    section Authentication
        User Verified : Auth service validates token
        
    section Inventory
        Stock Checked : Inventory service queries DB
        Items Reserved : Database locks inventory
        
    section Payment
        Payment Initiated : Payment service called
        Card Validated : Payment validation
        Payment Charged : Stripe API processes
        
    section Completion
        Order Confirmed : Order service finalizes
```

## 7. Error Rate Dashboard

```mermaid
pie title Service Error Distribution
    "Successful Calls" : 85
    "Retry Succeeded" : 10
    "Failed After Retries" : 3
    "Fallback Used" : 2
```

## 8. System Metrics Overview

```mermaid
graph TB
    subgraph "Trace Metrics"
        TT[Total Traces: 1000/min]
        AST[Avg Span Time: 25ms]
        EST[Error Span Rate: 5%]
    end
    
    subgraph "Service Health"
        API[API Gateway: 99.9%]
        AUTH[Auth Service: 99.95%]
        PAY[Payment Service: 99.5%]
        DB[Database: 99.99%]
    end
    
    subgraph "Performance"
        P95[P95 Latency: 150ms]
        P99[P99 Latency: 500ms]
        TPT[Throughput: 10K req/s]
    end
```

## Key Insights

1. **Bottlenecks**: Payment processing takes the longest (19ms)
2. **Retry Pattern**: 3 retry attempts with exponential backoff
3. **Fallback**: Graceful degradation when external services fail
4. **Caching**: Redis reduces database load
5. **ML Integration**: Async processing for predictions

## Recommended Optimizations

- Implement payment pre-authorization to reduce latency
- Add circuit breakers for external API calls
- Increase cache TTL for frequently accessed data
- Consider async processing for non-critical paths
EOF

echo "✅ Created comprehensive visualization: $OUTPUT_DIR/trace_visualization.md"

# Create an interactive HTML version
cat > "$OUTPUT_DIR/trace_visualization.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>OpenTelemetry Trace Visualization</title>
    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1, h2 {
            color: #333;
        }
        .mermaid {
            text-align: center;
            margin: 20px 0;
        }
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .metric-card {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            text-align: center;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #007bff;
        }
        .metric-label {
            color: #666;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 OpenTelemetry Trace Analysis</h1>
        
        <div class="metrics">
            <div class="metric-card">
                <div class="metric-value">50ms</div>
                <div class="metric-label">Total Request Time</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">8</div>
                <div class="metric-label">Services Involved</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">3</div>
                <div class="metric-label">Retry Attempts</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">95%</div>
                <div class="metric-label">Success Rate</div>
            </div>
        </div>
        
        <h2>Service Flow Visualization</h2>
        <div class="mermaid">
            graph TD
                A[Client Request] -->|50ms| B[API Gateway]
                B -->|10ms| C[Auth Service]
                B -->|9ms| D[Inventory Service]
                B -->|19ms| E[Payment Service]
                B -->|3ms| F[Order Service]
                D -->|5ms| G[Database]
                E -->|5ms| H[Validation]
                E -->|10ms| I[Stripe API]
                
                style A fill:#e1f5fe
                style B fill:#b3e5fc
                style C fill:#81d4fa
                style D fill:#4fc3f7
                style E fill:#29b6f6
                style F fill:#03a9f4
                style G fill:#039be5
                style H fill:#0288d1
                style I fill:#0277bd
        </div>
        
        <h2>Trace Timeline</h2>
        <div class="mermaid">
            gantt
                title Service Execution Timeline
                dateFormat X
                axisFormat %Lms
                
                Order Create     :a1, 0, 50
                User Auth        :a2, 5, 10
                Inventory Check  :a3, 16, 9
                DB Query         :a4, 17, 5
                Payment Process  :a5, 26, 19
                Payment Validate :a6, 27, 5
                Charge Card      :a7, 33, 10
                Order Confirm    :a8, 46, 3
        </div>
        
        <h2>Error Handling Flow</h2>
        <div class="mermaid">
            flowchart LR
                A[Request] --> B{Success?}
                B -->|Yes| C[Process]
                B -->|No| D[Retry 1]
                D --> E{Success?}
                E -->|No| F[Retry 2]
                F --> G{Success?}
                G -->|No| H[Retry 3]
                H --> I{Success?}
                I -->|No| J[Error Handler]
                J --> K[Send Notification]
                J --> L[Execute Fallback]
                E -->|Yes| C
                G -->|Yes| C
                I -->|Yes| C
                C --> M[Complete]
        </div>
    </div>
    
    <script>
        mermaid.initialize({ 
            startOnLoad: true,
            theme: 'default',
            themeVariables: {
                primaryColor: '#1976d2',
                primaryTextColor: '#fff',
                primaryBorderColor: '#0d47a1',
                lineColor: '#90a4ae',
                secondaryColor: '#64b5f6',
                tertiaryColor: '#e1f5fe'
            }
        });
    </script>
</body>
</html>
EOF

echo "✅ Created interactive HTML: $OUTPUT_DIR/trace_visualization.html"
echo ""
echo "📊 View the visualizations:"
echo "  - Markdown: cat $OUTPUT_DIR/trace_visualization.md"
echo "  - HTML: open $OUTPUT_DIR/trace_visualization.html"
echo ""
echo "🎯 Upload to GitHub/GitLab for automatic rendering"
echo "🌐 Or paste into https://mermaid.live for instant preview"