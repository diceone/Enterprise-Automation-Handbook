# Monitoring & Observability Deep Dive

A comprehensive guide for implementing enterprise-grade monitoring, logging, and tracing systems to achieve operational visibility, rapid incident detection, and effective troubleshooting.

## Table of Contents

1. [Observability Fundamentals](#observability-fundamentals)
2. [Metrics Collection and Analysis](#metrics-collection-and-analysis)
3. [Logging Best Practices](#logging-best-practices)
4. [Distributed Tracing](#distributed-tracing)
5. [Alert Management](#alert-management)
6. [Dashboard Design](#dashboard-design)
7. [SLA/SLO/SLI Framework](#slaslosli-framework)
8. [Log Aggregation Strategies](#log-aggregation-strategies)
9. [Performance Monitoring](#performance-monitoring)
10. [Troubleshooting with Observability](#troubleshooting-with-observability)

---

## Observability Fundamentals

### The Three Pillars of Observability

Observability is the ability to understand a system's internal state by examining its external outputs. The three pillars are:

```
┌─────────────────────────────────────┐
│     Observability (Three Pillars)   │
├─────────────────────────────────────┤
│                                     │
│  1. METRICS                         │
│     ├─ Time-series data             │
│     ├─ Discrete measurements        │
│     ├─ Example: CPU 45%, Memory 60% │
│     └─ Tools: Prometheus, Grafana   │
│                                     │
│  2. LOGS                            │
│     ├─ Discrete events              │
│     ├─ Unstructured/structured text │
│     ├─ Example: "User login failed" │
│     └─ Tools: ELK, Splunk, Loki     │
│                                     │
│  3. TRACES                          │
│     ├─ Request lifecycle            │
│     ├─ Service interactions         │
│     ├─ Example: Request A→B→C (5ms) │
│     └─ Tools: Jaeger, Zipkin, OTEL  │
│                                     │
└─────────────────────────────────────┘
```

### Observability vs Monitoring

```yaml
Monitoring:
  Definition: Collecting and checking metrics at specific intervals
  Focus: Pre-defined known issues
  Approach: Alerting on thresholds
  Limitation: Can't see unknown unknowns
  Example: "CPU > 80% triggers alert"

Observability:
  Definition: Understanding system behavior through external outputs
  Focus: Discovering unknown issues
  Approach: Asking arbitrary questions about data
  Benefit: Can investigate unexpected behavior
  Example: "Why did response time spike at 2pm?"

Relationship:
  ├─ Monitoring is a component of observability
  ├─ Observability requires good monitoring
  ├─ Need both for comprehensive visibility
  └─ Observability enables proactive monitoring
```

### Benefits of Observability

```yaml
Faster MTTR (Mean Time To Recovery):
  Before: 2-4 hours to find root cause
  After: 10-20 minutes with good observability
  Impact: $X per minute downtime reduction

Better User Experience:
  Detect performance issues before users complain
  Understand impact of changes
  Validate improvements

Reduced Toil:
  Automation of routine troubleshooting
  Self-service dashboards for teams
  Less manual log searching

Data-Driven Decision Making:
  Understand system behavior patterns
  Optimize based on real data
  Capacity planning informed by metrics

---

## Metrics Collection and Analysis

### Metrics Fundamentals

```yaml
Metric Types:

Counter:
  Definition: Always increasing value (never decreases)
  Example: Total requests served, Total errors
  Use case: Measuring cumulative activity
  Query: rate(requests_total[5m]) for rate of change

Gauge:
  Definition: Can go up or down
  Example: Current CPU%, Current memory, Active connections
  Use case: Point-in-time measurements
  Query: gauge_metric for current value

Histogram:
  Definition: Buckets of measurements
  Example: Request duration (1ms, 10ms, 100ms, 1s buckets)
  Use case: Understanding distribution of values
  Query: Percentiles, average bucket sizes

Summary:
  Definition: Quantile tracking
  Example: Request latency (p50, p95, p99)
  Use case: Tail latency measurements
  Query: Calculating percentiles over time
```

### Prometheus Setup

```yaml
# prometheus.yml - Configuration

global:
  scrape_interval: 15s       # How often to scrape
  evaluation_interval: 15s   # How often to evaluate rules
  external_labels:
    monitor: 'main-cluster'

scrape_configs:
  # Scrape Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  # Scrape Node Exporter (system metrics)
  - job_name: 'node'
    static_configs:
      - targets: 
        - 'node1.example.com:9100'
        - 'node2.example.com:9100'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
  
  # Scrape Kubernetes pods via service discovery
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__

# Alert Rules
rule_files:
  - 'alert_rules.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

### Metrics Instrumentation

```python
# Python Application Instrumentation with Prometheus Client

from prometheus_client import Counter, Gauge, Histogram, Summary
import time

# Counters - Total requests
requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

# Gauge - Current active connections
active_connections = Gauge(
    'active_connections',
    'Currently active connections'
)

# Histogram - Request duration buckets
request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    buckets=(0.001, 0.01, 0.1, 1.0, 10.0)
)

# Summary - Request latency percentiles
request_latency_summary = Summary(
    'http_request_latency_summary',
    'HTTP request latency (summary)'
)

# Using in application
def handle_request(method, endpoint):
    start = time.time()
    active_connections.inc()
    
    try:
        # Process request
        result = process(endpoint)
        status = 200
    except Exception as e:
        status = 500
        result = None
    finally:
        active_connections.dec()
    
    # Record metrics
    duration = time.time() - start
    requests_total.labels(method=method, endpoint=endpoint, status=status).inc()
    request_duration_seconds.labels(endpoint=endpoint).observe(duration)
    request_latency_summary.labels(endpoint=endpoint).observe(duration)
    
    return result
```

### Key Metrics to Monitor

```yaml
Application Metrics:
  Request Metrics:
    - request_rate (requests/sec by endpoint)
    - request_duration (p50, p95, p99 latency)
    - error_rate (% of failed requests)
    - status_codes (distribution of HTTP codes)
  
  Business Metrics:
    - orders_per_minute
    - revenue_per_hour
    - user_signups
    - session_duration
  
  System Resources:
    - cpu_usage
    - memory_usage
    - disk_usage
    - network_io

Infrastructure Metrics:
  Compute:
    - node_cpu_seconds_total
    - node_memory_bytes
    - container_cpu_usage_seconds
    - container_memory_usage_bytes
  
  Storage:
    - disk_read_bytes_total
    - disk_write_bytes_total
    - disk_space_available
    - disk_inode_free
  
  Network:
    - network_receive_bytes
    - network_transmit_bytes
    - network_connections_active
    - network_packets_dropped

Database Metrics:
  Query Performance:
    - query_duration_milliseconds
    - query_count_total
    - slow_query_count
    - query_error_count
  
  Connection Pool:
    - connection_pool_size
    - connection_pool_active
    - connection_pool_idle
    - connection_pool_overflow
  
  Replication:
    - replication_lag_bytes
    - replication_lag_seconds
    - replication_errors_total
```

---

## Logging Best Practices

### Structured Logging

```yaml
❌ Bad - Unstructured Log:
  "User john@example.com logged in from 192.168.1.1 at 2025-12-01T14:30:45Z"

✅ Good - Structured Log (JSON):
  {
    "timestamp": "2025-12-01T14:30:45Z",
    "level": "INFO",
    "event": "user_login",
    "user_id": "user_123",
    "email": "john@example.com",
    "ip_address": "192.168.1.1",
    "user_agent": "Mozilla/5.0...",
    "session_id": "sess_abc123",
    "duration_ms": 125
  }
```

### Log Levels

```yaml
DEBUG (Level 0):
  Purpose: Detailed diagnostic information
  Use: During development and troubleshooting
  Example: "Connection attempt #3 to database"
  Production: Usually disabled (verbose)

INFO (Level 1):
  Purpose: General informational messages
  Use: Important application events
  Example: "User login successful", "Service started"
  Production: Enabled, moderate volume

WARNING (Level 2):
  Purpose: Warning about potential issues
  Use: Degraded functionality, recoverable issues
  Example: "High memory usage: 85%", "Retry attempt 2 of 3"
  Production: Enabled, investigate

ERROR (Level 3):
  Purpose: Error conditions
  Use: Failures that need attention
  Example: "Database connection failed", "Invalid request format"
  Production: Enabled, alert on

CRITICAL/FATAL (Level 4):
  Purpose: Critical system failures
  Use: System might stop
  Example: "Out of disk space", "Core service crash"
  Production: Enabled, immediate alert

Volume by Level:
  ┌─────────────────────────────┐
  │ DEBUG: ████████████ 60%      │
  │ INFO:  ███████ 25%           │
  │ WARN:  ███ 10%               │
  │ ERROR: █ 4%                  │
  │ CRIT:  < 1%                  │
  └─────────────────────────────┘
```

### Structured Logging Implementation

```python
# Python structured logging with Python-JSON-Logger

import logging
import json
from pythonjsonlogger import jsonlogger

# Configure JSON logging
logger = logging.getLogger('app')
logger.setLevel(logging.INFO)

# JSON formatter
logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter()
logHandler.setFormatter(formatter)
logger.addHandler(logHandler)

# Usage
class RequestContext:
    def __init__(self, request_id, user_id):
        self.request_id = request_id
        self.user_id = user_id

# Logging with context
ctx = RequestContext("req_123", "user_456")
logger.info(
    "API request received",
    extra={
        "request_id": ctx.request_id,
        "user_id": ctx.user_id,
        "method": "POST",
        "endpoint": "/api/users",
        "status_code": 201,
        "duration_ms": 145,
        "client_ip": "192.168.1.1"
    }
)

# Output:
# {
#   "timestamp": "2025-12-01T14:30:45.123Z",
#   "level": "INFO",
#   "message": "API request received",
#   "request_id": "req_123",
#   "user_id": "user_456",
#   "method": "POST",
#   "endpoint": "/api/users",
#   "status_code": 201,
#   "duration_ms": 145,
#   "client_ip": "192.168.1.1"
# }
```

### Log Retention Policy

```yaml
Log Retention Strategy:

Hot Storage (0-7 days):
  Location: Fast, searchable (Elasticsearch)
  Cost: High ($X per GB)
  Access: Real-time queries
  Use case: Active troubleshooting
  Examples: Production errors, recent activity

Warm Storage (7-30 days):
  Location: Slower, less indexed (S3)
  Cost: Medium ($X per GB)
  Access: Manual analysis
  Use case: Week-long troubleshooting, audits
  Examples: Historical events, trends

Cold Storage (30-365 days):
  Location: Archive (Glacier, S3 Deep Archive)
  Cost: Low ($X per GB)
  Access: Rare, batch processing
  Use case: Compliance, audits
  Examples: Compliance records, legal holds

Lifecycle Rules:
  ├─ Day 7: Move from Elasticsearch to S3
  ├─ Day 30: Move to Glacier
  └─ Day 365: Delete (or keep per policy)

Cost Calculation:
  Daily log volume: 500GB
  Costs:
    ├─ Hot (7d @ $0.50/GB): $1,750/month
    ├─ Warm (23d @ $0.05/GB): $288/month
    └─ Cold (335d @ $0.01/GB): $168/month
    └─ Total: ~$2,200/month
```

---

## Distributed Tracing

### Trace Concepts

```yaml
Trace:
  Definition: Complete request path through system
  Contains: Multiple spans
  Example: Web request → API → DB → Cache

Span:
  Definition: Single operation/service in trace
  Duration: From start to end time
  Contains: Operation name, tags, logs, timestamps

Trace ID:
  Definition: Unique identifier for entire request
  Propagation: Passed through all services
  Use: Correlating all related spans

Span ID:
  Definition: Unique identifier for single operation
  Parent: Reference to parent span
  Use: Building request call graph

Example Trace:
  Trace ID: trace_abc123
  
  Span 1 (root): web-app-1 [0ms - 250ms]
    ├─ Span 2: api-gateway [10ms - 240ms]
    │   ├─ Span 3: user-service [15ms - 80ms]
    │   │   └─ Span 4: database [20ms - 70ms]
    │   ├─ Span 5: order-service [85ms - 200ms]
    │   │   ├─ Span 6: database [90ms - 150ms]
    │   │   └─ Span 7: cache [155ms - 195ms]
    │   └─ Span 8: response-builder [205ms - 235ms]
    └─ Span 9: render [245ms - 250ms]
```

### OpenTelemetry Implementation

```python
# OpenTelemetry tracing setup

from opentelemetry import trace, metrics
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from flask import Flask, request

# Configure Jaeger exporter
jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger-agent",
    agent_port=6831,
)

# Set up trace provider
trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(jaeger_exporter)
)

# Auto-instrumentation
app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()
SQLAlchemyInstrumentor().instrument()

# Manual span creation
tracer = trace.get_tracer(__name__)

@app.route('/api/users/<user_id>')
def get_user(user_id):
    with tracer.start_as_current_span("get_user") as span:
        span.set_attribute("user.id", user_id)
        span.set_attribute("http.method", request.method)
        
        # Nested span for database query
        with tracer.start_as_current_span("database_query"):
            user = query_database(user_id)
        
        # Nested span for enrichment
        with tracer.start_as_current_span("enrich_user_data"):
            enriched = enrich_user(user)
        
        span.set_attribute("user.enriched", True)
        return enriched

# Output in Jaeger UI:
# - Visualize call graph
# - See latency breakdown
# - Identify bottlenecks
# - Trace across services
```

### Trace Sampling

```yaml
Sampling Strategy:

Never Sampler:
  Rate: 0% (no traces)
  Use case: Testing, minimal overhead
  Tradeoff: No visibility

Always Sampler:
  Rate: 100% (all traces)
  Use case: Development, small scale
  Tradeoff: High cost, storage

Probability Sampler:
  Rate: X% probability
  Example: 10% of requests
  Calculation: Trace volume × 10% = manageable
  Tradeoff: Statistical sampling, miss rare issues

Adaptive Sampling:
  Rate: Varies by request type
  Example:
    ├─ Errors: 100% (always trace)
    ├─ Slow requests (>1s): 50%
    ├─ Normal requests: 5%
  Tradeoff: Captures important cases, cost-effective

Parent-based Sampler:
  Rule: Inherits parent's sampling decision
  Benefit: Traces stay together (sampled with parent)
  Use: Standard for distributed tracing

Cost Calculation (10 million requests/day):
  Always sample: 10M traces × $0.005 = $50,000/month
  10% sample: 1M traces × $0.005 = $5,000/month
  Adaptive (2% avg): 200K traces × $0.005 = $1,000/month
```

---

## Alert Management

### Alert Types

```yaml
Threshold-based Alerts:
  Rule: Metric > threshold for duration
  Example: "CPU > 80% for 5 minutes"
  Use case: Sudden spikes
  Configuration:
    metric: cpu_usage_percent
    threshold: 80
    duration: 5m
    action: page_oncall
  
  ❌ Problem: Alert fatigue
  ✅ Solution: Tuned thresholds, grace periods

Anomaly Detection:
  Rule: Detect unusual patterns
  Example: "Request rate 3 standard deviations from normal"
  Use case: Subtle issues, baseline changes
  Configuration:
    baseline_period: 7 days
    sensitivity: 3 std devs
    min_anomaly_duration: 10m
  
  ✅ Benefit: Catches issues without manual threshold tuning

Composite Alerts:
  Rule: Multiple conditions combined
  Example: "High CPU AND high memory AND high error rate"
  Use case: Correlate related signals
  Expression: (cpu > 80) AND (memory > 75) AND (errors > 100)
  
  ✅ Benefit: Reduces false positives

Rate-of-change Alerts:
  Rule: Rapid change in metric
  Example: "Error rate increased by 500% in 5 minutes"
  Use case: Catch degradation quickly
  Configuration:
    baseline_period: 5m
    change_threshold: 500%
    alert_delay: 1m
  
  ✅ Benefit: Early detection before threshold hit
```

### Alert Configuration

```yaml
# Prometheus Alert Rules (alert_rules.yml)

groups:
  - name: application_alerts
    interval: 1m
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }}"
          dashboard: "https://grafana/d/app-dashboard"
          runbook: "https://wiki/runbooks/high-error-rate"

      # High latency
      - alert: HighLatency
        expr: histogram_quantile(0.99, http_request_duration_seconds_bucket) > 1
        for: 5m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "High request latency"
          description: "p99 latency is {{ $value }}s"

      # Memory leak detection
      - alert: PossibleMemoryLeak
        expr: |
          (container_memory_usage_bytes - avg_over_time(container_memory_usage_bytes[1h])) 
          > 100 * 1024 * 1024
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "Possible memory leak detected"

      # Pod restart storm
      - alert: PodRestartingTooOften
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod restarting too frequently"
```

### Alert Routing and Notification

```yaml
# AlertManager Configuration (alertmanager.yml)

global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
  pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'

route:
  receiver: 'null'
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s           # Wait before sending first notification
  group_interval: 5m        # Wait before sending update
  repeat_interval: 4h       # Repeat if still firing
  
  routes:
    # Critical alerts → PagerDuty + Slack
    - match:
        severity: critical
      receiver: 'pagerduty'
      continue: true
    
    # Warning alerts → Slack only
    - match:
        severity: warning
      receiver: 'slack-warnings'
      group_wait: 1m
    
    # Team-specific routing
    - match:
        team: platform
      receiver: 'platform-team'
    
    - match:
        team: backend
      receiver: 'backend-team'

receivers:
  - name: 'null'          # Blackhole for non-routed alerts

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'pagerduty-integration-key'
        description: '{{ .GroupLabels.alertname }}'

  - name: 'slack-warnings'
    slack_configs:
      - channel: '#alerts-warnings'
        title: 'Warning Alert'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'platform-team'
    slack_configs:
      - channel: '#platform-team-alerts'
    email_configs:
      - to: 'platform-team@company.com'

inhibit_rules:
  # Don't alert if critical is already firing
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'service']
```

---

## Dashboard Design

### Dashboard Principles

```yaml
Principles:

1. Purpose-Driven:
   ├─ Know who views this dashboard
   ├─ Operations team dashboard ≠ Executive dashboard
   └─ Example: Ops sees percentiles, execs see business metrics

2. Information Hierarchy:
   ├─ Most important metric: Top-left, largest
   ├─ Supporting metrics: Below or right
   ├─ Details: Bottom or separate panels
   └─ Visual weight = importance

3. Context Clues:
   ├─ Baseline/threshold lines on charts
   ├─ Color coding (red=bad, green=good)
   ├─ Annotations for events
   └─ Related metrics nearby

4. Signal-to-Noise:
   ├─ Remove non-essential metrics
   ├─ Group related metrics
   ├─ Hide metrics unless needed
   └─ Alerts show in dedicated section

5. Quick Comprehension:
   ├─ Understand status in 10 seconds
   ├─ Use numbers, not just charts
   ├─ Color status indicators
   └─ Single-metric visualizations for key stats
```

### Dashboard Examples

```yaml
Operations/On-Call Dashboard:
  Layout:
    ┌─────────────────────────────────────┐
    │ System Status  │ Alert Count: 3     │
    ├─────────────────────────────────────┤
    │ Request Rate   │ Error Rate         │
    │ (req/s)        │ (% 5xx)            │
    ├─────────────────────────────────────┤
    │ p50 Latency    │ p95 Latency        │
    │ p99 Latency    │ Max Latency        │
    ├─────────────────────────────────────┤
    │ CPU Usage      │ Memory Usage       │
    │ Disk Usage     │ Network I/O        │
    ├─────────────────────────────────────┤
    │ Active Alerts (scrollable list)    │
    │ ├─ High Error Rate - API Service  │
    │ ├─ High Memory - Cache Service    │
    │ └─ Pod Restarting - Web Service   │
    ├─────────────────────────────────────┤
    │ Recent Events Timeline              │
    │ ├─ 14:32 - Deployment completed   │
    │ ├─ 14:28 - Error spike noticed    │
    │ └─ 14:25 - Traffic spike          │
    └─────────────────────────────────────┘

Executive/Business Dashboard:
  Layout:
    ┌─────────────────────────────────────┐
    │ Revenue (today)  │ Users (online)   │
    │ $X,XXX           │ XX,XXX           │
    ├─────────────────────────────────────┤
    │ Orders/min       │ Uptime %         │
    │ XXX              │ 99.95%           │
    ├─────────────────────────────────────┤
    │ Conversion Rate  │ Avg Order Value  │
    │ X.X%             │ $XXX             │
    ├─────────────────────────────────────┤
    │ Revenue Trend    │ System Health    │
    │ (7-day chart)    │ (status dot)     │
    └─────────────────────────────────────┘

Service-Specific Dashboard:
  Layout:
    ┌─────────────────────────────────────┐
    │ Auth Service - Prod                 │
    ├─────────────────────────────────────┤
    │ Requests      │ Success Rate        │
    │ Error Rate    │ Latency (p99)       │
    ├─────────────────────────────────────┤
    │ Database Connections                │
    │ Cache Hit Rate                      │
    │ Failed Logins                       │
    ├─────────────────────────────────────┤
    │ Dependency Status                   │
    │ └─ Database: Healthy               │
    │ └─ Cache: Healthy                  │
    │ └─ Message Queue: Healthy          │
    ├─────────────────────────────────────┤
    │ Related Services                    │
    │ └─ See dependent services status   │
    └─────────────────────────────────────┘
```

---

## SLA/SLO/SLI Framework

### Definitions

```yaml
SLA (Service Level Agreement):
  Definition: Contract between provider and customer
  Example: "99.9% uptime guaranteed"
  Consequence: Financial penalty if not met
  Who cares: Business, customers, contracts
  Management: Legal, Sales
  Typical: 99.0% to 99.99% uptime

SLO (Service Level Objective):
  Definition: Target reliability internally set
  Example: "Target 99.95% uptime"
  Consequence: Team tracking and improvement
  Who cares: Engineering, Product
  Management: Product, Engineering leadership
  Typical: SLO > SLA (provide buffer)
  Relationship to SLA: SLO = SLA - buffer

SLI (Service Level Indicator):
  Definition: Actual measured metric
  Example: "Last month: 99.96% uptime"
  How measured: (successful requests / total requests) × 100
  Data: Actual system behavior
  Who cares: Everyone
  Management: Observability, monitoring
  Relationship: (SLI vs SLO) = error budget consumed

Relationship:
  SLI measures reality
  SLO is our target
  SLA is our promise
  
  If SLI < SLO: Consuming error budget
  If SLI < SLA: Breach (penalties apply)
```

### Error Budget

```yaml
Error Budget = (1 - SLO) × Total Time

Example (99.9% SLO, 30 days):
  
  30 days = 43,200 minutes
  Error budget = 0.1% × 43,200 = 43.2 minutes
  
  Allowed downtime:
    ├─ Per month: 43.2 minutes
    ├─ Per week: ~10.3 minutes
    ├─ Per day: ~1.4 minutes
    └─ Per hour: ~3.6 seconds

Using Error Budget:
  ├─ Unplanned incident (20 min): 43% of budget used
  ├─ Planned maintenance (15 min): 35% of budget used
  ├─ Remaining budget: 8.2 minutes (19% of budget)
  └─ Action: Reduce risk, avoid new deployments

Decision Framework:
  ├─ If budget > 20%: Can do risky changes
  ├─ If budget 5-20%: Conservative changes only
  ├─ If budget < 5%: Freeze changes, focus on stability
  └─ If consumed: Post-incident review required

Cost-Benefit Analysis:
  New feature delivery risk: Loss of 5 minutes uptime
  But: Feature generates $10K/hour revenue
  
  Decision: Ship it (error budget provides buffer)
```

### SLO Implementation

```yaml
# Define SLOs for each service

auth_service:
  slo: 99.95
  measurement_window: rolling_30_days
  sli_metrics:
    - availability: (successful_auth_attempts / total_auth_attempts) × 100
      threshold: > 99.95
    - latency_p99: auth_request_latency_p99
      threshold: < 500ms
    - error_rate: auth_service_errors / auth_service_requests
      threshold: < 0.05%
  
  error_budget_exhaustion:
    - If SLI < 99.90: Warning (50% budget used)
    - If SLI < 99.50: Critical (90% budget used)
    - Action: Prevent new deployments

api_gateway:
  slo: 99.99
  measurement_window: rolling_7_days
  sli_metrics:
    - availability: (2xx+3xx responses / total requests) × 100
      threshold: > 99.99
    - latency_p99: gateway_request_latency_p99
      threshold: < 100ms
  
  error_budget: 6.05 minutes per week

database_service:
  slo: 99.9
  measurement_window: calendar_month
  sli_metrics:
    - availability: (successful_queries / total_queries) × 100
      threshold: > 99.9
    - connection_availability: (available_connections / max_connections) × 100
      threshold: > 99.0
```

---

## Log Aggregation Strategies

### ELK Stack Implementation

```yaml
# Elasticsearch, Logstash, Kibana

Filebeat Configuration (filebeat.yml):
  
  filebeat.inputs:
    - type: log
      enabled: true
      paths:
        - /var/log/app/*.log
      multiline.pattern: '^\['
      multiline.negate: true
      multiline.match: after
      fields:
        service: api-gateway
        environment: production

  output.elasticsearch:
    hosts: ["elasticsearch:9200"]
    index: "api-gateway-%{+yyyy.MM.dd}"
    
  processors:
    - add_fields:
        target: environment
        fields:
          datacenter: us-east-1
          pod_name: api-gateway-5f8d6c
    - add_kubernetes_metadata:
        host: ${NODE_NAME}
    - decode_json_fields:
        fields: ["message"]
        target: "json"

Logstash Filter (logstash.conf):
  
  input {
    elasticsearch {
      hosts => "elasticsearch:9200"
      index => "raw-logs-%{+YYYY.MM.dd}"
    }
  }
  
  filter {
    # Parse JSON logs
    json {
      source => "message"
      target => "parsed_log"
    }
    
    # Extract fields
    mutate {
      add_fields => {
        "[@metadata][index_name]" => "logs-%{+YYYY.MM.dd}"
      }
    }
    
    # Geoip lookup
    geoip {
      source => "client_ip"
    }
  }
  
  output {
    elasticsearch {
      hosts => "elasticsearch:9200"
      index => "%{[@metadata][index_name]}"
      document_type => "_doc"
    }
    
    # Also output to S3 for archival
    s3 {
      bucket => "log-archive"
      region => "us-east-1"
      prefix => "logs/%{+YYYY}/%{+MM}/%{+dd}/"
    }
  }

Kibana Visualization:
  
  Dashboard: API Service Logs
    ├─ Pie chart: Status code distribution
    ├─ Time series: Error rate over time
    ├─ Top 10: Most frequent errors
    ├─ Geo map: Requests by location
    ├─ Table: Recent errors (searchable)
    └─ Markdown: Runbook links
```

### Loki Alternative (Lightweight)

```yaml
# Grafana Loki - Log aggregation for containers

Loki Configuration (loki-config.yaml):
  
  auth_enabled: false
  
  ingester:
    chunk_idle_period: 3m
    max_chunk_age: 1h
    max_streams_per_user: 10000
  
  limits_config:
    enforce_metric_name: false
    reject_old_samples: true
    reject_old_samples_max_age: 168h
  
  schema_config:
    configs:
      - from: 2020-10-24
        store: boltdb-shipper
        object_store: filesystem
        schema:
          version: v11
          index:
            prefix: index_
            period: 24h
  
  storage_config:
    boltdb_shipper:
      active_index_directory: /loki/boltdb-shipper-active
      cache_location: /loki/boltdb-shipper-cache
    filesystem:
      directory: /loki/chunks

Promtail Configuration (promtail-config.yaml):
  
  clients:
    - url: http://loki:3100/loki/api/v1/push
  
  scrape_configs:
    - job_name: docker
      static_configs:
        - targets:
            - localhost
          labels:
            job: docker
            __path__: /var/lib/docker/containers/*/*-json.log
      pipeline_stages:
        - json:
            expressions:
              log: log
              stream: stream
        - labels:
            stream: stream

# Query logs in Grafana
# {job="api-gateway"} |= "error" | json | level="ERROR"
```

---

## Performance Monitoring

### Application Performance Monitoring (APM)

```yaml
APM Metrics to Track:

Response Time:
  Metrics:
    - Min response time
    - Max response time
    - Average response time
    - p50, p95, p99 percentiles
  Tracking: Histogram or summary metric
  Alert: p99 > 1 second

Throughput:
  Metrics:
    - Requests per second
    - Requests per minute
    - Concurrent users
  Tracking: Counter metric
  Alert: When varies significantly from baseline

Error Rate:
  Metrics:
    - % of failed requests (4xx, 5xx)
    - By type (validation, service, database)
    - By endpoint
  Tracking: Counter by status code
  Alert: > 1% error rate

Apdex Score (Application Performance Index):
  Formula: (Satisfied + Tolerated/2) / Total
  
  Example (1 second threshold):
    ├─ Satisfied (< 1s): 450 requests
    ├─ Tolerated (1-4s): 40 requests
    ├─ Frustrated (> 4s): 10 requests
    └─ Apdex = (450 + 40/2) / 500 = 0.94 (94%)
  
  Interpretation:
    ├─ 0.94-1.0: Excellent
    ├─ 0.85-0.93: Good
    ├─ 0.70-0.84: Acceptable
    ├─ 0.50-0.69: Poor
    └─ < 0.50: Unacceptable
```

### Infrastructure Performance

```yaml
CPU Performance:
  Metrics:
    - User CPU: Application code
    - System CPU: OS kernel
    - I/O Wait: Waiting for disk/network
    - Idle: Unused capacity
  
  Analysis:
    High I/O Wait → Disk/network bottleneck
    High User CPU → Application optimization needed
    High System CPU → OS tuning needed
    Low Idle → Close to saturation

Memory Performance:
  Metrics:
    - Used memory
    - Free memory
    - Cached memory
    - Available memory (free + cache)
  
  Concerns:
    - Sustained growth → Memory leak
    - OOM kills → Increase allocation
    - Cache efficiency → Tuning opportunity

Disk Performance:
  Metrics:
    - Read/write IOPS (operations/sec)
    - Read/write throughput (MB/sec)
    - I/O wait time
    - Queue depth
  
  Indicators:
    High queue depth → Disk saturation
    High I/O wait → Application waiting for disk
    Low throughput → Consider SSD
```

---

## Troubleshooting with Observability

### Troubleshooting Workflow

```
1. Detect Problem
   └─ Alert triggered or user report
   
2. Gather Context
   ├─ Check dashboard
   ├─ Review recent changes
   ├─ Check for related alerts
   └─ Get system metrics snapshot
   
3. Narrow Scope
   ├─ Is it application or infrastructure?
   ├─ Which service/component affected?
   ├─ What changed recently?
   └─ Is it widespread or isolated?
   
4. Deep Dive Investigation
   ├─ Review logs for errors
   ├─ Examine trace data for bottlenecks
   ├─ Check metrics for anomalies
   └─ Review infrastructure metrics
   
5. Form Hypothesis
   Example: "High DB query latency causing slow API responses"
   
6. Test Hypothesis
   ├─ Reproduce issue in test environment
   ├─ Verify logs support theory
   ├─ Check traces show bottleneck
   └─ Monitor metrics during test
   
7. Implement Fix
   ├─ Database query optimization
   ├─ Add indexing
   ├─ Reduce query scope
   └─ Cache frequently accessed data
   
8. Verify Fix
   ├─ Monitor metrics for improvement
   ├─ Check error rate decreased
   ├─ Validate user experience
   └─ Confirm alert resolves
   
9. Post-Incident
   ├─ Document root cause
   ├─ Create runbook if applicable
   ├─ Add monitoring/alerting
   └─ Prevent recurrence
```

### Case Study: Slow API Response

```yaml
Scenario: API response time increased from 100ms to 2 seconds

Detection:
  Alert: API latency p99 > 1 second for 5 minutes

Initial Investigation:
  Dashboard check:
    ├─ API error rate: Normal (< 0.1%)
    ├─ API request rate: Normal (~100 req/s)
    ├─ CPU usage: 45% (normal)
    ├─ Memory usage: 60% (normal)
    ├─ Database CPU: 80% (higher than normal)
    └─ Database query count: 2x normal

Hypothesis:
  "Database is slower than usual, API waiting for responses"

Investigation:
  Logs: "[ERROR] Query timeout after 30s" appearing frequently
  Traces:
    ├─ User request spans DB query section
    ├─ DB query taking 2-5 seconds (normally 100ms)
    ├─ Multiple queries per request
    └─ Some queries running in parallel
  
  Database metrics:
    ├─ Slow queries: 500+ per minute (normally 10)
    ├─ Query lock waits: High
    ├─ Connection pool: Near capacity (95/100)
    └─ Disk I/O: High read operations

Root Cause Analysis:
  Hypothesis: Table lock contention
  Confirmation: Logs show "Waiting for table lock"

Immediate Fix:
  ├─ Add query timeout to prevent hanging
  ├─ Increase connection pool size (100 → 150)
  ├─ Kill long-running queries manually
  └─ Monitor for recovery

Root Cause Fix:
  ├─ Review slow queries
  ├─ Add missing index on frequently filtered column
  ├─ Optimize query to reduce lock scope
  ├─ Implement connection pooling at application level

Prevention:
  ├─ Alert: Slow query count > 100/min
  ├─ Alert: Database connection pool > 80%
  ├─ Runbook: Database Performance Degradation
  ├─ Add connection pool monitoring
  └─ Query plan reviews in code review
```

---

## References

- [Google Cloud SRE Book - Monitoring](https://sre.google/books/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [OpenTelemetry](https://opentelemetry.io/)
- [The ELK Stack](https://www.elastic.co/what-is/elk-stack)
- [Observability Engineering - O'Reilly](https://www.oreilly.com/library/view/observability-engineering/)

---

**Author**: Michael Vogeler  
**Last Updated**: December 2025  
**Maintained By**: Platform & Observability Team
