# Logging Best Practices

A comprehensive guide for implementing enterprise-grade logging strategies, structured logging, log aggregation, and analysis techniques for DevOps environments.

## Table of Contents

1. [Logging Fundamentals](#logging-fundamentals)
2. [Structured Logging](#structured-logging)
3. [Log Levels and Severity](#log-levels-and-severity)
4. [Log Retention and Storage](#log-retention-and-storage)
5. [Log Aggregation Platforms](#log-aggregation-platforms)
6. [Application Logging](#application-logging)
7. [Infrastructure Logging](#infrastructure-logging)
8. [Kubernetes Logging](#kubernetes-logging)
9. [Log Analysis and Querying](#log-analysis-and-querying)
10. [Logging Best Practices and Anti-Patterns](#logging-best-practices-and-anti-patterns)

---

## Logging Fundamentals

### Why Logging Matters

```yaml
Purposes of Logging:

Debugging:
  - Find root cause of issues
  - Trace execution flow
  - Understand unexpected behavior
  - Speed up problem resolution

Monitoring & Alerting:
  - Detect errors in real-time
  - Track application behavior
  - Set up alert rules
  - Proactive issue detection

Compliance & Audit:
  - Track user actions
  - Security event tracking
  - Regulatory requirements
  - Forensic analysis

Performance Analysis:
  - Identify slow operations
  - Bottleneck detection
  - Resource usage tracking
  - Optimization opportunities

Cost Reduction:
  - Avoid unnecessary debugging
  - Faster incident resolution
  - Reduce mean time to recovery (MTTR)
  - Prevent costly outages
```

### Logging vs Other Observability Pillars

```yaml
Logging:
  Definition: Discrete events, text-based information
  Granularity: Event-level, detailed
  Volume: High (millions of events/day)
  Storage: Weeks to months
  Use Case: Understanding "what happened"
  Tools: ELK, Loki, Splunk, CloudWatch
  Cost: Medium to High

Metrics:
  Definition: Aggregated numerical data
  Granularity: Per-minute averages
  Volume: Low (thousands/day)
  Storage: Years
  Use Case: Trends, alerting, dashboards
  Tools: Prometheus, Grafana, Datadog
  Cost: Low

Tracing:
  Definition: Request path through system
  Granularity: Transaction-level
  Volume: Medium (thousands/day)
  Storage: Days to weeks
  Use Case: Performance, call flows
  Tools: Jaeger, Zipkin, OpenTelemetry
  Cost: High

Logging Scope:
  - Application logs: App behavior, errors, business events
  - Infrastructure logs: System events, kernel messages
  - Audit logs: Access, changes, compliance
  - Security logs: Authentication, authorization, threats
```

---

## Structured Logging

### Why Structured Logging

```yaml
Unstructured Logging (❌ Bad):
  Log Entry: "2025-12-02 14:32:15 User john@example.com logged in from 192.168.1.1"
  Problems:
    - Hard to parse automatically
    - Can't filter by specific fields
    - Human-readable but machine-unfriendly
    - Inconsistent formats

Structured Logging (✅ Good):
  Log Entry: {"timestamp": "2025-12-02T14:32:15Z", "event": "user_login", 
              "user_id": "user_123", "email": "john@example.com", "ip": "192.168.1.1"}
  Benefits:
    - Easy to parse and index
    - Query by specific fields
    - Consistent format
    - Machine and human readable
    - Searchable and analyzable
```

### JSON Structured Logging Format

```json
{
  "timestamp": "2025-12-02T14:32:15.123Z",
  "level": "INFO",
  "logger": "auth_service",
  "event_type": "user_login",
  "request_id": "req_abc123def456",
  "trace_id": "trace_xyz789",
  "span_id": "span_001",
  "user_id": "user_123",
  "email": "john@example.com",
  "client_ip": "192.168.1.1",
  "user_agent": "Mozilla/5.0...",
  "method": "POST",
  "endpoint": "/api/auth/login",
  "status_code": 200,
  "duration_ms": 145,
  "session_id": "sess_abc123",
  "environment": "production",
  "service": "auth-service",
  "version": "1.2.3",
  "message": "User successfully logged in",
  "tags": ["auth", "security", "user-action"],
  "context": {
    "source": "web",
    "mfa_enabled": true,
    "login_method": "email_password"
  }
}
```

### Structured Logging Implementation

```python
# Python structured logging with structlog

import structlog
from datetime import datetime

# Configure structlog
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Logging with context
def handle_user_login(email, password, ip_address):
    try:
        logger.info(
            "login_attempt",
            email=email,
            ip_address=ip_address,
            timestamp=datetime.utcnow().isoformat()
        )
        
        # Authenticate user
        user = authenticate_user(email, password)
        
        logger.info(
            "login_success",
            user_id=user.id,
            email=email,
            ip_address=ip_address,
            duration_ms=145,
            mfa_enabled=user.mfa_enabled
        )
        
        return user
        
    except AuthenticationError as e:
        logger.warning(
            "login_failed",
            email=email,
            ip_address=ip_address,
            reason="invalid_credentials",
            attempt_number=increment_failed_attempts(email)
        )
        raise
    
    except Exception as e:
        logger.error(
            "login_error",
            email=email,
            ip_address=ip_address,
            error_type=type(e).__name__,
            error_message=str(e),
            exc_info=True
        )
        raise

# Output (JSON formatted):
# {"timestamp": "2025-12-02T14:32:15Z", "level": "info", "event": "login_attempt", 
#  "email": "john@example.com", "ip_address": "192.168.1.1"}
```

---

## Log Levels and Severity

### Standard Log Levels

```yaml
DEBUG (Level 0):
  Purpose: Detailed diagnostic information
  When to Use: Development, troubleshooting
  Example: "Connection attempt #3 to database"
  Production: Disabled (verbose)
  Line Count: ~60% of logs

INFO (Level 1):
  Purpose: General information about normal operation
  When to Use: Important events
  Example: "Service started", "User logged in successfully"
  Production: Enabled (regular)
  Line Count: ~25% of logs

WARNING (Level 2):
  Purpose: Warning about potential issues
  When to Use: Degraded functionality, recoverable errors
  Example: "High memory usage (85%)", "Retry attempt 2 of 3"
  Production: Enabled (important)
  Line Count: ~10% of logs

ERROR (Level 3):
  Purpose: Error conditions
  When to Use: Failures requiring attention
  Example: "Database connection failed", "Invalid request format"
  Production: Enabled (alert)
  Line Count: ~4% of logs

CRITICAL/FATAL (Level 4):
  Purpose: Critical system failures
  When to Use: System might stop
  Example: "Out of disk space", "Core service crash"
  Production: Enabled (immediate)
  Line Count: < 1% of logs

Log Level Distribution (Production):
  ┌──────────────────────────┐
  │ DEBUG:    Disabled        │
  │ INFO:     ████████████ 25%│
  │ WARNING:  ██████ 10%      │
  │ ERROR:    ██ 4%           │
  │ CRITICAL: < 1%            │
  └──────────────────────────┘
```

### Custom Log Levels

```python
# Custom log levels for business events

import logging

# Define custom levels
BUSINESS_EVENT = 35  # Between WARNING (30) and ERROR (40)
SECURITY = 38        # Between WARNING and ERROR

logging.addLevelName(BUSINESS_EVENT, "BUSINESS")
logging.addLevelName(SECURITY, "SECURITY")

logger = logging.getLogger(__name__)

# Log business events
logger.log(BUSINESS_EVENT, "order_created", 
          order_id="ord_123", amount=99.99, user_id="user_456")

# Log security events
logger.log(SECURITY, "unauthorized_access_attempt",
          user_id="user_789", endpoint="/admin/settings", 
          reason="insufficient_permissions")
```

---

## Log Retention and Storage

### Log Retention Policy

```yaml
Storage Strategy (3-Tier):

Tier 1 - Hot Storage (0-7 days):
  Location: Searchable (Elasticsearch, Splunk)
  Cost: High ($0.50/GB per month)
  Access: Real-time, interactive
  Use Case: Active troubleshooting, alerts
  Retention: 7 days
  
  Daily volume: 500GB
  Weekly cost: 500GB × 7 × $0.50 = $1,750
  Monthly cost: ~$2,500

Tier 2 - Warm Storage (7-30 days):
  Location: Slower, less indexed (S3)
  Cost: Medium ($0.05/GB per month)
  Access: Manual queries, bulk analysis
  Use Case: Week-long troubleshooting, trends
  Retention: 23 days
  
  Daily volume: 500GB
  Weekly cost: 500GB × 23 × $0.05 = $575
  Monthly cost: ~$287

Tier 3 - Cold Storage (30-365 days):
  Location: Archive (Glacier, Deep Archive)
  Cost: Low ($0.01/GB per month)
  Access: Rare, batch processing
  Use Case: Compliance, audits, legal holds
  Retention: 335 days
  
  Daily volume: 500GB
  Weekly cost: 500GB × 335 × $0.01 = $1,675
  Monthly cost: ~$168

Lifecycle Management:
  Day 1-7:   Keep in hot storage (Elasticsearch)
  Day 7-30:  Archive to warm storage (S3)
  Day 30+:   Move to cold storage (Glacier)
  Day 365+:  Delete (or keep per compliance)

Total Monthly Cost (500GB/day):
  Hot:  $2,500
  Warm: $287
  Cold: $168
  ────────────
  Total: $2,955/month

Cost Optimization:
  - Compress before archival (50-70% reduction)
  - Remove debug logs in production
  - Aggregate non-critical logs
  - Set appropriate retention policies
```

### Compression and Archival

```yaml
# Log archival with compression

Compression Strategies:

gzip:
  Ratio: 10:1 to 20:1 (typical)
  Speed: Fast
  Cloud support: Good
  Use case: S3, Glacier
  Command: gzip logs.tar

zstd:
  Ratio: 15:1 to 25:1 (better)
  Speed: Very fast
  Cloud support: Limited
  Use case: Local archival
  Command: zstd logs.tar

Archival Workflow:
  1. Collect 24-hour log files (500GB)
  2. Compress: 500GB → 25GB (gzip 20:1)
  3. Transfer to S3 warm storage
  4. After 30 days: Move to Glacier
  5. Compress again if needed (zstd)
  6. Archive lifecycle policy applies
  
  Cost Savings:
    - Uncompressed: $0.05/GB × 500GB = $25/day
    - Compressed: $0.05/GB × 25GB = $1.25/day
    - Monthly savings: ~$712
```

---

## Log Aggregation Platforms

### ELK Stack (Elasticsearch, Logstash, Kibana)

```yaml
# Complete ELK setup

docker-compose.yml:
  version: '3.8'
  services:
    elasticsearch:
      image: docker.elastic.co/elasticsearch/elasticsearch:8.10.0
      environment:
        - discovery.type=single-node
        - xpack.security.enabled=false
      ports:
        - "9200:9200"
      volumes:
        - es_data:/usr/share/elasticsearch/data

    logstash:
      image: docker.elastic.co/logstash/logstash:8.10.0
      volumes:
        - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
      ports:
        - "5000:5000"
      depends_on:
        - elasticsearch

    kibana:
      image: docker.elastic.co/kibana/kibana:8.10.0
      ports:
        - "5601:5601"
      environment:
        - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      depends_on:
        - elasticsearch

  volumes:
    es_data:
```

### Loki - Lightweight Log Aggregation

```yaml
# Grafana Loki setup (lightweight, efficient)

# loki-config.yaml
auth_enabled: false

ingester:
  chunk_idle_period: 3m
  max_chunk_age: 1h
  max_streams_per_user: 10000
  chunk_retain_period: 0

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

# Promtail configuration (log collector)
# promtail-config.yaml
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

  - job_name: kubernetes
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod

# Query logs in Grafana:
# {job="kubernetes"} |= "error" | json | level="ERROR"
# {job="docker"} | json | response_time > 1000
```

---

## Application Logging

### Logging Strategy by Application Type

```yaml
Web Application:
  Critical Logs:
    - Request entry/exit (with request ID)
    - Authentication/authorization events
    - Database queries (with duration)
    - External API calls (with status)
    - Errors and exceptions
    - Business transactions
  
  Log Points:
    - Request handler entry
    - Database before/after
    - API call before/after
    - Exception handlers
    - Significant business logic
  
  Metrics to Log:
    - Request ID (for tracing)
    - User ID
    - Response time
    - Status code
    - Error type
    - Query count

Microservice:
  Critical Logs:
    - Service startup/shutdown
    - Health check results
    - Dependency health (database, cache, other services)
    - Request/response summaries
    - Circuit breaker state changes
    - Retry attempts
  
  Log Points:
    - Service initialization
    - Dependency checks
    - Request handlers
    - Circuit breaker triggers
    - Retry logic
  
  Metrics to Log:
    - Service version
    - Dependency status
    - Response time
    - Error rate
    - Retry count

Batch Job:
  Critical Logs:
    - Job start/end
    - Progress updates (every N items)
    - Errors and failures
    - Summary statistics
    - Failed item details
  
  Log Points:
    - Job initialization
    - Progress tracking
    - Error handling
    - Job completion
  
  Metrics to Log:
    - Job ID
    - Items processed
    - Items failed
    - Duration
    - Success rate
```

### Application Logging Example

```python
# Flask application with structured logging

from flask import Flask, request, jsonify
import structlog
from functools import wraps
import time
import uuid

app = Flask(__name__)
logger = structlog.get_logger()

def log_request(f):
    """Decorator to log all requests"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        request_id = str(uuid.uuid4())
        start_time = time.time()
        
        logger.info(
            "request_started",
            request_id=request_id,
            method=request.method,
            endpoint=request.path,
            ip_address=request.remote_addr,
            user_agent=request.user_agent.string
        )
        
        try:
            result = f(*args, **kwargs)
            
            duration_ms = (time.time() - start_time) * 1000
            logger.info(
                "request_completed",
                request_id=request_id,
                method=request.method,
                endpoint=request.path,
                status_code=200,
                duration_ms=duration_ms
            )
            
            return result
            
        except Exception as e:
            duration_ms = (time.time() - start_time) * 1000
            logger.error(
                "request_error",
                request_id=request_id,
                method=request.method,
                endpoint=request.path,
                error_type=type(e).__name__,
                error_message=str(e),
                duration_ms=duration_ms,
                exc_info=True
            )
            raise
    
    return decorated_function

@app.route('/api/users/<user_id>')
@log_request
def get_user(user_id):
    logger.info("fetching_user", user_id=user_id)
    
    # Get user from database
    user = db.query(User).filter_by(id=user_id).first()
    
    if not user:
        logger.warning("user_not_found", user_id=user_id)
        return jsonify({"error": "User not found"}), 404
    
    logger.info("user_fetched", user_id=user_id, email=user.email)
    
    return jsonify(user.to_dict()), 200

if __name__ == '__main__':
    logger.info("application_started", version="1.0.0", environment="production")
    app.run(debug=False)
```

---

## Infrastructure Logging

### System Logging (syslog)

```yaml
# Syslog configuration

/etc/rsyslog.d/custom.conf:
  
  # Log format with ISO timestamp
  $ActionFileDefaultTemplate RSYSLOG_FileFormat
  $DateFormat iso8601
  
  # Application logs
  :programname, isequal, "nginx" /var/log/nginx/syslog.log
  :programname, isequal, "postgres" /var/log/postgresql/syslog.log
  :programname, isequal, "docker" /var/log/docker/syslog.log
  
  # Forward to central syslog server
  *.* @@syslog.example.com:514

# Kernel and system logs
kern.*           /var/log/kernel.log
auth,authpriv.*  /var/log/auth.log
cron.*           /var/log/cron.log
mail.*           /var/log/mail.log
```

### Journald (Systemd Logging)

```bash
# View logs
journalctl                                    # All logs
journalctl -u nginx                          # Service logs
journalctl -u nginx --since "1 hour ago"    # Recent logs
journalctl -u nginx -f                       # Follow logs
journalctl -u nginx -p err                   # Error level only

# Export logs
journalctl -u nginx -o json > logs.json
journalctl -u nginx -o json-pretty

# Persistent storage (survives reboot)
mkdir -p /var/log/journal
systemctl restart systemd-journald
```

---

## Kubernetes Logging

### Pod Logging

```yaml
# Kubernetes pod logs

# View pod logs
kubectl logs pod-name                      # Current logs
kubectl logs pod-name -f                   # Follow logs
kubectl logs pod-name -c container-name   # Specific container
kubectl logs pod-name --tail=100           # Last 100 lines
kubectl logs pod-name --since=1h           # Last hour

# Export pod logs
kubectl logs pod-name > pod.log
kubectl logs deployment/my-app -l app=api > app.log

# Log configuration in deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logging-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: my-app:1.0
        
        # Send stdout to container logs
        stdout: true
        stderr: true
        
        # Configure log level via env
        env:
        - name: LOG_LEVEL
          value: "INFO"
        
        # Volume for local logging
        volumeMounts:
        - name: logs
          mountPath: /var/log/app
      
      volumes:
      - name: logs
        emptyDir: {}
```

### Cluster-Wide Logging with Fluent-bit

```yaml
# Fluent-bit DaemonSet for K8s cluster logging

apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush        5
        Daemon       Off
        Log_Level    info

    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token

    [OUTPUT]
        Name  loki
        Match *
        Host  loki
        Port  3100
        Labels job=kubernetes-cluster

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:2.1.0
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc/
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
```

---

## Log Analysis and Querying

### Kibana Query Language (KQL)

```
# Kibana Query Examples

# Basic field matching
status: 200
level: ERROR

# Range queries
response_time >= 1000
status_code > 500

# Boolean operators
level: ERROR AND service: auth-service
method: POST OR method: PUT
NOT status: 200

# Complex queries
(service: api-gateway OR service: auth-service) AND level: ERROR
status: 500 AND duration_ms > 2000 AND timestamp >= now-1h

# Wildcard matching
message: "Connection*"
user_email: "*@example.com"

# Phrase matching
"database connection failed"
```

### Loki Query Language (LogQL)

```
# Loki Query Examples

# Label matching
{job="kubernetes"}
{service="auth", level="error"}

# Multiple conditions
{job="api"} | json | status >= 500

# Pattern matching
{job="api"} |= "error"
{job="api"} != "health_check"

# Metrics from logs
count_over_time({job="api"} |= "error" [5m])
rate({job="api"} |= "error" [5m])

# Line filters
{job="api"} | json | duration > 1000
{job="api"} | regex "error_code=(?P<code>\d+)"

# Label filters
{job="api"} | json | level="ERROR" | service="auth"
```

---

## Logging Best Practices and Anti-Patterns

### Best Practices Checklist

```yaml
Planning & Strategy:
  - [ ] Define logging strategy for each service
  - [ ] Identify critical events to log
  - [ ] Set retention policies
  - [ ] Plan storage infrastructure
  - [ ] Define naming conventions

Implementation:
  - [ ] Use structured (JSON) logging
  - [ ] Include request ID/correlation ID
  - [ ] Add appropriate context (user_id, service, version)
  - [ ] Use correct log levels
  - [ ] Include meaningful messages
  - [ ] Don't log sensitive data
  - [ ] Add timing information
  - [ ] Include error stack traces

Operations:
  - [ ] Set up log aggregation
  - [ ] Configure alerts on errors
  - [ ] Monitor log volume
  - [ ] Plan for log retention
  - [ ] Regular log analysis
  - [ ] Track slow queries/operations
  - [ ] Review and audit logs

Maintenance:
  - [ ] Review logs regularly
  - [ ] Adjust log levels as needed
  - [ ] Update retention policies
  - [ ] Archive old logs
  - [ ] Test log recovery
  - [ ] Document log format
  - [ ] Train team on log searching
```

### Anti-Patterns to Avoid

```yaml
❌ Anti-Pattern: Logging Everything
  Problem: Massive log volume, high cost, noise
  Example: DEBUG logs in production
  Solution: Appropriate log levels, filter logs

❌ Anti-Pattern: Unstructured Logs
  Problem: Hard to search, parse, analyze
  Example: "User did something at some time"
  Solution: Use JSON structured logging

❌ Anti-Pattern: Logging Sensitive Data
  Problem: Security risk, compliance violation
  Example: Logging passwords, tokens, PII
  Solution: Never log secrets, redact sensitive data

❌ Anti-Pattern: No Context
  Problem: Logs are useless without context
  Example: "Error occurred"
  Solution: Include request IDs, user IDs, timestamps

❌ Anti-Pattern: Swallowing Exceptions
  Problem: No visibility into errors
  Example: try/except with no logging
  Solution: Always log exceptions with context

❌ Anti-Pattern: Single Giant Log File
  Problem: Slow, difficult to manage
  Example: All logs in /var/log/app.log
  Solution: Structured logging with aggregation

✅ Best Practice: Structured Logging
✅ Best Practice: Correlation IDs
✅ Best Practice: Appropriate Log Levels
✅ Best Practice: Centralized Aggregation
✅ Best Practice: Searchable Format
✅ Best Practice: Retention Policy
✅ Best Practice: Log Monitoring & Alerts
```

---

## References

- [Structured Logging](https://www.kartar.net/2015/12/structured-logging/)
- [ELK Stack Documentation](https://www.elastic.co/what-is/elk-stack)
- [Grafana Loki](https://grafana.com/oss/loki/)
- [JSON Logging Standard](https://github.com/graylog2/graylog2-docs/wiki/JSON-logging-format)
- [Kubernetes Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/)
- [Syslog Protocol (RFC 3164)](https://tools.ietf.org/html/rfc3164)

---

**Author**: Michael Vogeler  
**Last Updated**: December 2025  
**Maintained By**: Platform & Observability Team
