# Disaster Recovery & Business Continuity

Comprehensive guide to disaster recovery planning, business continuity strategies, automated failover, and recovery procedures for enterprise-grade infrastructure.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Core Concepts](#core-concepts)
3. [RTO/RPO Planning](#rtorpo-planning)
4. [Backup Strategy](#backup-strategy)
5. [High Availability Architecture](#high-availability-architecture)
6. [Failover Automation](#failover-automation)
7. [Recovery Procedures](#recovery-procedures)
8. [Testing & Validation](#testing--validation)
9. [Incident Response](#incident-response)
10. [Monitoring & Alerting](#monitoring--alerting)
11. [Documentation](#documentation)

## Project Structure

### Recommended Directory Layout

```
disaster-recovery/
├── terraform/
│   ├── modules/
│   │   ├── multi-region/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   ├── backup-vault/
│   │   ├── route53-failover/
│   │   └── cross-region-db/
│   ├── environments/
│   │   ├── primary/
│   │   ├── secondary/
│   │   └── tertiary/
│   └── README.md
├── ansible/
│   ├── roles/
│   │   ├── backup/
│   │   ├── replication/
│   │   ├── failover/
│   │   ├── recovery/
│   │   └── verification/
│   ├── playbooks/
│   │   ├── dr-setup.yml
│   │   ├── backup-full.yml
│   │   ├── failover.yml
│   │   ├── recovery.yml
│   │   └── dr-test.yml
│   ├── inventory/
│   └── group_vars/
├── kubernetes/
│   ├── backup/
│   │   ├── velero-config.yaml
│   │   └── storage-class.yaml
│   ├── failover/
│   │   └── multi-cluster-setup.yaml
│   ├── recovery/
│   │   └── restore-procedures.yaml
│   └── monitoring/
├── scripts/
│   ├── backup-full.sh
│   ├── backup-incremental.sh
│   ├── verify-backup.sh
│   ├── failover.sh
│   ├── recovery.sh
│   ├── health-check.sh
│   └── dr-test.sh
├── docs/
│   ├── rto-rpo-targets.md
│   ├── recovery-plan.md
│   ├── failover-procedures.md
│   ├── runbook.md
│   └── contact-list.md
└── monitoring/
    ├── prometheus-rules.yaml
    ├── dashboards.yaml
    └── alerts.yaml
```

## Core Concepts

### 1. RTO (Recovery Time Objective)

**RTO** is the maximum acceptable downtime before business impact becomes critical.

```
RTO Tiers:
- Critical Systems: 15-30 minutes
- Important Systems: 1-4 hours
- Standard Systems: 4-24 hours
- Non-critical: 24+ hours
```

**RTO Formula:**
```
Actual RTO = Detection Time + Failover Time + Recovery Time
```

**Example:**
```
Critical Database RTO = 2 min + 3 min + 10 min = 15 minutes
```

### 2. RPO (Recovery Point Objective)

**RPO** is the maximum acceptable data loss (time between backups).

```
RPO Tiers:
- Critical Data: Real-time (0 minutes)
- Important Data: 5-15 minutes
- Standard Data: 1-4 hours
- Non-critical: 24 hours
```

**RPO Formula:**
```
Actual RPO = Time Since Last Successful Backup
```

**Example:**
```
Continuous Replication RPO = 0 minutes (real-time)
Hourly Snapshots RPO = 0-60 minutes
Daily Backups RPO = 0-24 hours
```

### 3. Disaster Classification

```yaml
Level 1 - Single Component Failure:
  - Single server down
  - RTO: < 15 minutes
  - RPO: Near real-time
  - Action: Auto-failover
  - Recovery: 10-15 minutes

Level 2 - Regional Outage:
  - Entire data center down
  - RTO: 30 minutes - 2 hours
  - RPO: < 15 minutes
  - Action: Manual failover to secondary region
  - Recovery: 2-4 hours

Level 3 - Multi-Region Failure:
  - Primary and secondary regions down
  - RTO: 4-24 hours
  - RPO: < 24 hours
  - Action: Activate tertiary region / on-prem
  - Recovery: 12-48 hours

Level 4 - Complete Infrastructure Loss:
  - All regions compromised
  - RTO: > 24 hours
  - RPO: > 24 hours
  - Action: Full rebuild from archives
  - Recovery: 48+ hours
```

### 4. Backup Strategy Hierarchy

```
Backup Levels:

Level 1 - Real-time Replication (RPO: 0 min)
  └── Synchronous replication to standby
      Acceptable Latency: < 100ms

Level 2 - Near Real-time Snapshots (RPO: 5-15 min)
  └── Automated snapshots every 5-15 minutes
      Storage: Local/Regional

Level 3 - Hourly Backups (RPO: 1 hour)
  └── Scheduled backups every hour
      Storage: Regional storage

Level 4 - Daily Backups (RPO: 24 hours)
  └── Full daily backups
      Storage: Multi-region storage + archives

Level 5 - Weekly Archives (RPO: 1 week)
  └── Long-term compliance archives
      Storage: Glacier/Archive storage
      Retention: 7+ years
```

## RTO/RPO Planning

### Defining RTO/RPO Matrix

```yaml
# Service RTO/RPO Matrix
services:
  - name: "Production Database"
    criticality: "CRITICAL"
    rto_minutes: 15
    rpo_minutes: 5
    backup_type: "continuous_replication"
    failover_type: "automatic"
    
  - name: "API Gateway"
    criticality: "CRITICAL"
    rto_minutes: 10
    rpo_minutes: 0
    backup_type: "multi_region_active_active"
    failover_type: "automatic"
    
  - name: "Cache Layer (Redis)"
    criticality: "HIGH"
    rto_minutes: 30
    rpo_minutes: 15
    backup_type: "periodic_snapshots"
    failover_type: "automatic"
    
  - name: "Batch Processing"
    criticality: "MEDIUM"
    rto_minutes: 240  # 4 hours
    rpo_minutes: 1440  # 24 hours
    backup_type: "daily_snapshots"
    failover_type: "manual"
    
  - name: "Analytics Database"
    criticality: "LOW"
    rto_minutes: 1440  # 24 hours
    rpo_minutes: 1440
    backup_type: "weekly_full"
    failover_type: "manual"
```

### Terraform for RTO/RTO Infrastructure

```hcl
# modules/rto-rpo/main.tf

# Critical: Active-Active across regions
resource "aws_elasticache_replication_group" "critical_cache" {
  replication_group_description = "Critical cache with automatic failover"
  engine                       = "redis"
  engine_version              = "7.0"
  node_type                   = "cache.r6g.xlarge"
  num_cache_clusters          = 3
  
  # Multi-AZ
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  # Read replicas in other regions
  depends_on = [aws_elasticache_replication_group.replica_cache]
  
  tags = {
    RTO = "10"  # minutes
    RPO = "0"   # real-time replication
  }
}

# Cross-region replica (async replication)
resource "aws_elasticache_replication_group" "replica_cache" {
  provider                     = aws.secondary_region
  replication_group_description = "Cross-region replica cache"
  engine                       = "redis"
  engine_version              = "7.0"
  
  # Replica node type can be smaller
  node_type                   = "cache.t4g.medium"
  num_cache_clusters          = 2
  
  # Read-only replica
  replicate_source_cluster_id = aws_elasticache_replication_group.critical_cache.id
  
  tags = {
    RTO = "60"  # Can accept longer RTO
    RPO = "5"   # Async replication, up to 5 min lag
  }
}

# Database with PITR (Point-in-time recovery)
resource "aws_db_instance" "critical_database" {
  identifier            = "production-postgres-critical"
  engine               = "postgres"
  instance_class       = "db.r6i.2xlarge"
  allocated_storage    = 100
  
  # Multi-AZ for high availability
  multi_az = true
  
  # Backup for RPO compliance
  backup_retention_period = 35  # 35 days for weekly backups
  backup_window          = "03:00-04:00"
  copy_tags_to_snapshot  = true
  delete_automated_backups = false
  
  # Read replicas
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Cross-region read replica
  depends_on = [aws_db_instance.replica_database]
  
  tags = {
    RTO = "15"  # 15 minutes
    RPO = "5"   # 5 minutes max data loss
  }
}

# Cross-region read replica
resource "aws_db_instance" "replica_database" {
  provider           = aws.secondary_region
  identifier         = "production-postgres-replica"
  replicate_source_db = aws_db_instance.critical_database.identifier
  
  instance_class = "db.r6i.large"
  
  # Skip backup on replica
  skip_final_snapshot = true
  
  # Enable automatic promotion on primary failure
  auto_minor_version_upgrade = true
  
  tags = {
    RTO = "60"  # Manual failover, takes longer
    RPO = "5"   # Replication lag
  }
}
```

## Backup Strategy

### Automated Full Backup

```bash
#!/bin/bash
# scripts/backup-full.sh

set -e

BACKUP_DIR="/var/backups/postgresql"
S3_BUCKET="company-disaster-recovery"
RETENTION_DAYS=35
LOG_FILE="/var/log/backup-full.log"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# Create backup directory
mkdir -p "${BACKUP_DIR}"

log "=== Starting full database backup ==="

# Full backup with compression
BACKUP_FILE="${BACKUP_DIR}/full-backup-$(date +%Y%m%d-%H%M%S).sql.gz"
BACKUP_START=$(date +%s)

PGPASSWORD="${DB_PASSWORD}" pg_dump \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d "${DB_NAME}" \
  --verbose \
  --compress=9 \
  --jobs=4 \
  --format=directory \
  "${BACKUP_FILE}" 2>&1 | tee -a "${LOG_FILE}"

BACKUP_END=$(date +%s)
BACKUP_DURATION=$((BACKUP_END - BACKUP_START))

if [ $? -eq 0 ]; then
  log "✓ Backup completed successfully (Duration: ${BACKUP_DURATION}s)"
  
  BACKUP_SIZE=$(du -sh "${BACKUP_FILE}" | cut -f1)
  log "Backup size: ${BACKUP_SIZE}"
  
  # Create backup manifest
  cat > "${BACKUP_FILE}.manifest" << EOF
{
  "type": "full",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "database": "${DB_NAME}",
  "host": "${DB_HOST}",
  "size": "${BACKUP_SIZE}",
  "duration_seconds": ${BACKUP_DURATION},
  "retention_days": ${RETENTION_DAYS}
}
EOF
  
  # Upload to S3 with versioning
  log "Uploading to S3..."
  aws s3 cp "${BACKUP_FILE}" \
    "s3://${S3_BUCKET}/full-backups/$(date +%Y/%m/%d)/" \
    --storage-class INTELLIGENT_TIERING \
    --sse aws:kms \
    --sse-kms-key-id "${KMS_KEY_ID}" \
    --metadata "host=${DB_HOST},database=${DB_NAME},rpo=5,rto=15" \
    2>&1 | tee -a "${LOG_FILE}"
  
  aws s3 cp "${BACKUP_FILE}.manifest" \
    "s3://${S3_BUCKET}/full-backups/$(date +%Y/%m/%d)/" \
    --storage-class INTELLIGENT_TIERING \
    2>&1 | tee -a "${LOG_FILE}"
  
  if [ $? -eq 0 ]; then
    log "✓ Backup uploaded to S3"
    
    # Cleanup old local backups
    find "${BACKUP_DIR}" -name "full-backup-*.sql.gz" -mtime +3 -delete
    find "${BACKUP_DIR}" -name "*.manifest" -mtime +3 -delete
    
    # Send success notification
    aws sns publish \
      --topic-arn "${SNS_TOPIC_ARN}" \
      --subject "✓ Database Full Backup Successful: ${DB_NAME}" \
      --message "Backup completed successfully

Database: ${DB_NAME}
Size: ${BACKUP_SIZE}
Duration: ${BACKUP_DURATION}s
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Location: s3://${S3_BUCKET}/full-backups/$(date +%Y/%m/%d)/"
    
    log "✓ Notification sent"
  else
    log "✗ S3 upload failed"
    exit 1
  fi
else
  log "✗ Backup failed"
  
  # Send failure notification
  aws sns publish \
    --topic-arn "${SNS_TOPIC_ARN}" \
    --subject "✗ Database Full Backup FAILED: ${DB_NAME}" \
    --message "Database backup failed - immediate attention required

Database: ${DB_NAME}
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Error: Check logs at ${LOG_FILE}"
  
  exit 1
fi
```

### Incremental Backup with WAL Archiving

```yaml
# Ansible playbook for incremental backup setup
---
- name: Setup incremental backup with WAL archiving
  hosts: database_servers
  become: yes
  vars:
    wal_archive_dir: /var/lib/pgsql/wal_archive
    s3_wal_bucket: "company-disaster-recovery/wal-archives"

  tasks:
    - name: Create WAL archive directory
      file:
        path: "{{ wal_archive_dir }}"
        state: directory
        owner: postgres
        group: postgres
        mode: '0700'

    - name: Configure WAL archiving in postgresql.conf
      lineinfile:
        path: /etc/postgresql/15/main/postgresql.conf
        regexp: "{{ item.regexp }}"
        line: "{{ item.line }}"
        state: present
      loop:
        - regexp: '^archive_mode'
          line: 'archive_mode = on'
        - regexp: '^archive_command'
          line: "archive_command = 'aws s3 cp %p s3://{{ s3_wal_bucket }}/$(date +%Y%m%d)/%f --sse aws:kms --sse-kms-key-id {{ kms_key_id }}'"
        - regexp: '^archive_timeout'
          line: 'archive_timeout = 300'
      notify: restart postgresql

    - name: Deploy WAL monitoring script
      template:
        src: monitor-wal-archiving.sh.j2
        dest: /usr/local/bin/monitor-wal-archiving.sh
        owner: root
        group: root
        mode: '0755'

    - name: Create WAL monitoring cron job
      cron:
        name: "Monitor WAL archiving"
        user: root
        minute: "*/5"
        job: "/usr/local/bin/monitor-wal-archiving.sh >> /var/log/wal-monitor.log 2>&1"

    - name: Verify WAL archiving setup
      shell: |
        psql -U postgres -c "SHOW archive_command;"
        psql -U postgres -c "SHOW archive_mode;"
      register: wal_config

    - name: Display WAL configuration
      debug:
        var: wal_config.stdout_lines
```

### Backup Verification Strategy

```bash
#!/bin/bash
# scripts/verify-backup.sh

set -e

BACKUP_FILE="${1:-}"
TEMP_DIR="/tmp/backup-verify-$$"
TEST_DB="backup_verify_test"

if [ -z "${BACKUP_FILE}" ]; then
  echo "Usage: $0 <backup-file>"
  exit 1
fi

if [ ! -f "${BACKUP_FILE}" ]; then
  echo "Backup file not found: ${BACKUP_FILE}"
  exit 1
fi

echo "=== Verifying Backup ==="
echo "File: ${BACKUP_FILE}"
echo "Size: $(du -h ${BACKUP_FILE} | cut -f1)"

# Create temporary directory for extraction
mkdir -p "${TEMP_DIR}"

# Verify backup integrity
echo "Checking backup integrity..."
if gzip -t "${BACKUP_FILE}" 2>/dev/null; then
  echo "✓ Backup file integrity verified"
else
  echo "✗ Backup file is corrupted"
  rm -rf "${TEMP_DIR}"
  exit 1
fi

# Extract backup to temporary directory
echo "Extracting backup..."
tar -tzf "${BACKUP_FILE}" > /dev/null 2>&1 && echo "✓ TAR integrity verified" || echo "✗ TAR integrity failed"

# Test restore to temporary database
echo "Testing restore to temporary database..."

# Create test database
PGPASSWORD="${DB_PASSWORD}" psql \
  -h "${DB_HOST}" \
  -U "${DB_USER}" \
  -c "CREATE DATABASE ${TEST_DB};" 2>/dev/null || true

# Attempt restore
RESTORE_LOG="/tmp/restore-test-$$.log"
gunzip -c "${BACKUP_FILE}" | \
  PGPASSWORD="${DB_PASSWORD}" psql \
    -h "${DB_HOST}" \
    -U "${DB_USER}" \
    -d "${TEST_DB}" \
    > "${RESTORE_LOG}" 2>&1

if [ ${PIPESTATUS[1]} -eq 0 ]; then
  echo "✓ Backup restore test passed"
  
  # Verify table count
  TABLE_COUNT=$(PGPASSWORD="${DB_PASSWORD}" psql \
    -h "${DB_HOST}" \
    -U "${DB_USER}" \
    -d "${TEST_DB}" \
    -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';")
  
  echo "✓ Tables restored: ${TABLE_COUNT}"
  
  # Cleanup
  PGPASSWORD="${DB_PASSWORD}" psql \
    -h "${DB_HOST}" \
    -U "${DB_USER}" \
    -c "DROP DATABASE ${TEST_DB};" 2>/dev/null || true
  
  echo "✓ Backup verification PASSED"
else
  echo "✗ Backup restore test FAILED"
  cat "${RESTORE_LOG}"
  rm -rf "${TEMP_DIR}" "${RESTORE_LOG}"
  exit 1
fi

rm -rf "${TEMP_DIR}" "${RESTORE_LOG}"

# Send verification report
aws sns publish \
  --topic-arn "${SNS_TOPIC_ARN}" \
  --subject "✓ Backup Verification Passed: $(basename ${BACKUP_FILE})" \
  --message "Backup verification completed successfully

File: $(basename ${BACKUP_FILE})
Size: $(du -h ${BACKUP_FILE} | cut -f1)
Tables: ${TABLE_COUNT}
Verification Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

## High Availability Architecture

### Active-Active Configuration

```yaml
# Kubernetes multi-region active-active setup
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: dr-config
  namespace: kube-system
data:
  primary_region: us-east-1
  secondary_region: us-west-2
  failover_threshold: "30"  # seconds
  health_check_interval: "10"  # seconds

---
apiVersion: v1
kind: Service
metadata:
  name: global-endpoint
  namespace: default
spec:
  type: ExternalName
  externalName: global-lb.example.com
  ports:
  - port: 443
    targetPort: 443

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dr-replication
  namespace: databases
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: replication
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: replication
    ports:
    - protocol: TCP
      port: 5432
```

### Terraform Multi-Region Setup

```hcl
# Terraform multi-region configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary region
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

# Secondary region (DR)
provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}

# Route53 health check for failover
resource "aws_route53_health_check" "primary" {
  provider          = aws.primary
  type              = "HTTPS"
  resource_path     = "/health"
  fqdn              = aws_lb.primary.dns_name
  port              = 443
  failure_threshold = 3
  request_interval  = 10
  measure_latency   = true

  tags = {
    Name = "primary-health-check"
  }
}

resource "aws_route53_health_check" "secondary" {
  provider          = aws.secondary
  type              = "HTTPS"
  resource_path     = "/health"
  fqdn              = aws_lb.secondary.dns_name
  port              = 443
  failure_threshold = 3
  request_interval  = 10
  measure_latency   = true

  tags = {
    Name = "secondary-health-check"
  }
}

# Failover routing policy
resource "aws_route53_record" "failover" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.example.com"
  type    = "A"

  # Primary routing
  alias {
    name                   = aws_lb.primary.dns_name
    zone_id                = aws_lb.primary.zone_id
    evaluate_target_health = true
  }

  set_identifier       = "Primary-${var.region_primary}"
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary.id

  depends_on = [aws_lb.primary]
}

# Secondary failover record
resource "aws_route53_record" "failover_secondary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.example.com"
  type    = "A"

  alias {
    name                   = aws_lb.secondary.dns_name
    zone_id                = aws_lb.secondary.zone_id
    evaluate_target_health = true
  }

  set_identifier       = "Secondary-${var.region_secondary}"
  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = aws_route53_health_check.secondary.id

  depends_on = [aws_lb.secondary]
}
```

## Failover Automation

### Automated Failover Script

```bash
#!/bin/bash
# scripts/failover.sh

set -e

LOG_FILE="/var/log/failover.log"
FAILOVER_START=$(date +%s)

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

error_exit() {
  log "✗ ERROR: $1"
  notify_status "FAILED" "$1"
  exit 1
}

notify_status() {
  local status=$1
  local message=$2
  
  aws sns publish \
    --topic-arn "${SNS_TOPIC_ARN}" \
    --subject "Failover ${status}: $(hostname)" \
    --message "${message}

Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Host: $(hostname)
Duration: $(($(date +%s) - FAILOVER_START))s"
}

log "=== Starting Failover Procedure ==="

# Step 1: Stop primary database connections
log "Step 1: Isolating primary database..."
PGPASSWORD="${PRIMARY_DB_PASSWORD}" psql \
  -h "${PRIMARY_DB_HOST}" \
  -U postgres \
  -c "SELECT pg_wal_replay_resume();" 2>/dev/null || true

sleep 2

# Step 2: Promote standby to primary
log "Step 2: Promoting standby database..."
PGPASSWORD="${STANDBY_DB_PASSWORD}" psql \
  -h "${STANDBY_DB_HOST}" \
  -U postgres \
  -c "SELECT pg_promote();" || error_exit "Failed to promote standby"

# Wait for promotion
sleep 10

# Step 3: Verify standby is now primary
log "Step 3: Verifying promotion..."
PROMOTE_CHECK=$(PGPASSWORD="${STANDBY_DB_PASSWORD}" psql \
  -h "${STANDBY_DB_HOST}" \
  -U postgres \
  -t -c "SELECT NOT pg_is_in_recovery();")

if [ "${PROMOTE_CHECK}" != "t" ]; then
  error_exit "Standby promotion verification failed"
fi

log "✓ Standby successfully promoted to primary"

# Step 4: Update DNS/Route53
log "Step 4: Updating Route53 failover..."
aws route53 change-resource-record-sets \
  --hosted-zone-id "${ROUTE53_ZONE_ID}" \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "db.internal.example.com",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [{"Value": "'${STANDBY_DB_HOST}'"}]
      }
    }]
  }' || error_exit "Failed to update Route53"

log "✓ DNS updated"

# Step 5: Update application configuration
log "Step 5: Updating application configuration..."
aws ssm put-parameter \
  --name "/app/db/primary_host" \
  --value "${STANDBY_DB_HOST}" \
  --overwrite \
  --type "String" || error_exit "Failed to update SSM parameters"

# Step 6: Restart applications
log "Step 6: Restarting applications..."
systemctl restart app-service || error_exit "Application restart failed"

# Step 7: Verify connectivity
log "Step 7: Verifying connectivity..."
sleep 5
PGPASSWORD="${STANDBY_DB_PASSWORD}" psql \
  -h "${STANDBY_DB_HOST}" \
  -U postgres \
  -c "SELECT version();" || error_exit "Connectivity verification failed"

FAILOVER_END=$(date +%s)
FAILOVER_DURATION=$((FAILOVER_END - FAILOVER_START))

log "✓ Failover completed successfully (Duration: ${FAILOVER_DURATION}s)"
notify_status "SUCCESS" "Failover completed successfully in ${FAILOVER_DURATION}s"
```

### Ansible Failover Playbook

```yaml
# Ansible playbook for automated failover
---
- name: Automated database failover
  hosts: localhost
  gather_facts: no
  vars:
    failover_timeout: 300
    health_check_retries: 5

  tasks:
    - name: Detect primary failure
      block:
        - name: Health check on primary
          wait_for:
            host: "{{ primary_db_host }}"
            port: 5432
            timeout: 10
          register: primary_health
          ignore_errors: yes

        - name: Retry health check
          wait_for:
            host: "{{ primary_db_host }}"
            port: 5432
            timeout: 5
          retries: "{{ health_check_retries }}"
          delay: 2
          register: health_retry
          ignore_errors: yes

        - name: Confirm primary failure
          set_fact:
            primary_failed: true
          when: health_retry.failed

    - name: Execute failover procedures
      block:
        - name: Promote standby database
          command: |
            PGPASSWORD="{{ standby_db_password }}" psql \
            -h {{ standby_db_host }} \
            -U postgres \
            -c "SELECT pg_promote();"
          register: promote_result

        - name: Wait for promotion to complete
          pause:
            seconds: 10

        - name: Verify promotion
          postgresql_query:
            db: postgres
            login_host: "{{ standby_db_host }}"
            login_user: postgres
            login_password: "{{ standby_db_password }}"
            query: "SELECT NOT pg_is_in_recovery() as is_primary;"
          register: promotion_check
          until: promotion_check.query_result[0][0].is_primary == true
          retries: 5
          delay: 5

        - name: Update Route53
          route53:
            zone: "{{ route53_zone }}"
            record: "db.internal.example.com"
            type: CNAME
            value: "{{ standby_db_host }}"
            state: present
            ttl: 60

        - name: Update SSM parameters
          aws_ssm_parameter:
            name: "/app/db/primary_host"
            value: "{{ standby_db_host }}"
            overwrite: yes
            type: String

        - name: Restart application services
          systemd:
            name: "{{ item }}"
            state: restarted
          loop:
            - app-service
            - worker-service

        - name: Verify application connectivity
          wait_for:
            host: localhost
            port: 8080
            timeout: 30

      when: primary_failed

    - name: Send notifications
      sns:
        msg: |
          Failover completed successfully
          Primary: {{ primary_db_host }}
          New Primary: {{ standby_db_host }}
          Timestamp: {{ ansible_date_time.iso8601 }}
        subject: "Database Failover Completed"
        topic_arn: "{{ sns_topic_arn }}"
```

## Recovery Procedures

### Database Recovery from Backup

```bash
#!/bin/bash
# scripts/recovery.sh

set -e

BACKUP_FILE="${1:-}"
TARGET_DB="${2:-restored_db}"
LOG_FILE="/var/log/recovery.log"

if [ -z "${BACKUP_FILE}" ]; then
  echo "Usage: $0 <backup-file> [target-database]"
  exit 1
fi

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

RECOVERY_START=$(date +%s)

log "=== Starting Database Recovery ==="
log "Source: ${BACKUP_FILE}"
log "Target: ${TARGET_DB}"

# Step 1: Validate backup file
log "Step 1: Validating backup..."
if [ ! -f "${BACKUP_FILE}" ]; then
  log "✗ Backup file not found: ${BACKUP_FILE}"
  exit 1
fi

if ! gzip -t "${BACKUP_FILE}" 2>/dev/null; then
  log "✗ Backup file is corrupted"
  exit 1
fi

log "✓ Backup validation passed"

# Step 2: Create target database
log "Step 2: Creating target database..."
PGPASSWORD="${DB_PASSWORD}" psql \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -c "CREATE DATABASE ${TARGET_DB};" 2>/dev/null || true

log "✓ Target database ready"

# Step 3: Restore backup
log "Step 3: Restoring backup (this may take a while)..."
RESTORE_LOG="/tmp/restore-$$.log"

gunzip -c "${BACKUP_FILE}" | \
  PGPASSWORD="${DB_PASSWORD}" pg_restore \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --username="${DB_USER}" \
    --dbname="${TARGET_DB}" \
    --verbose \
    --jobs=4 \
    2>&1 | tee "${RESTORE_LOG}"

if [ ${PIPESTATUS[1]} -eq 0 ]; then
  log "✓ Restore completed successfully"
else
  log "✗ Restore failed - see ${RESTORE_LOG}"
  exit 1
fi

# Step 4: Verify restoration
log "Step 4: Verifying restoration..."

TABLE_COUNT=$(PGPASSWORD="${DB_PASSWORD}" psql \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d "${TARGET_DB}" \
  -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';")

ROW_COUNT=$(PGPASSWORD="${DB_PASSWORD}" psql \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d "${TARGET_DB}" \
  -t -c "SELECT SUM(n_live_tup) FROM pg_stat_user_tables;")

log "✓ Tables: ${TABLE_COUNT}"
log "✓ Total rows: ${ROW_COUNT}"

# Step 5: Run integrity checks
log "Step 5: Running integrity checks..."

PGPASSWORD="${DB_PASSWORD}" psql \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d "${TARGET_DB}" \
  -c "REINDEX DATABASE ${TARGET_DB};" 2>&1 | tee -a "${RESTORE_LOG}"

RECOVERY_END=$(date +%s)
RECOVERY_DURATION=$((RECOVERY_END - RECOVERY_START))

log "✓ Recovery completed (Duration: ${RECOVERY_DURATION}s)"

# Send notification
aws sns publish \
  --topic-arn "${SNS_TOPIC_ARN}" \
  --subject "✓ Database Recovery Completed" \
  --message "Database successfully restored

Source: $(basename ${BACKUP_FILE})
Target: ${TARGET_DB}
Tables: ${TABLE_COUNT}
Rows: ${ROW_COUNT}
Duration: ${RECOVERY_DURATION}s
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

### Application Recovery Checklist

```yaml
# Recovery checklist
application_recovery:
  pre_recovery:
    - name: "Notify stakeholders"
      action: "Contact incident commander and team leads"
      
    - name: "Document current state"
      action: "Take screenshots, logs, error messages"
      
    - name: "Assess impact"
      action: "Determine affected services and data"
      
    - name: "Plan recovery order"
      action: "Prioritize critical vs non-critical services"

  recovery_phases:
    - phase: 1
      name: "Critical Infrastructure"
      components:
        - "Database clusters"
        - "Cache layers"
        - "Load balancers"
      expected_duration: "15-30 minutes"
      
    - phase: 2
      name: "Core Services"
      components:
        - "API gateways"
        - "Auth services"
        - "Message queues"
      expected_duration: "30-60 minutes"
      
    - phase: 3
      name: "Supporting Services"
      components:
        - "Analytics"
        - "Logging"
        - "Monitoring"
      expected_duration: "1-2 hours"
      
    - phase: 4
      name: "Validation"
      components:
        - "Health checks"
        - "Smoke tests"
        - "Integration tests"
      expected_duration: "30 minutes"

  post_recovery:
    - name: "Verify functionality"
      action: "Run automated test suites"
      
    - name: "Monitor metrics"
      action: "Watch error rates, latency, resource usage"
      
    - name: "Collect logs"
      action: "Gather logs from all components"
      
    - name: "Document incident"
      action: "Write incident report with timeline"
```

## Testing & Validation

### Disaster Recovery Testing Script

```bash
#!/bin/bash
# scripts/dr-test.sh

set -e

TEST_DIR="/tmp/dr-test-$$"
TEST_DATE=$(date +%Y%m%d-%H%M%S)
TEST_REPORT="/var/log/dr-test-${TEST_DATE}.log"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${TEST_REPORT}"
}

mkdir -p "${TEST_DIR}"

log "=== Starting Disaster Recovery Test ==="
log "Test ID: ${TEST_DATE}"

# Test 1: Backup creation
log "Test 1: Verify backup creation..."
/usr/local/bin/backup-full.sh >> "${TEST_REPORT}" 2>&1
LATEST_BACKUP=$(ls -t /var/backups/postgresql/full-backup-*.sql.gz | head -1)
log "✓ Backup created: ${LATEST_BACKUP}"

# Test 2: Backup verification
log "Test 2: Verify backup integrity..."
/usr/local/bin/verify-backup.sh "${LATEST_BACKUP}" >> "${TEST_REPORT}" 2>&1
log "✓ Backup integrity verified"

# Test 3: Test restore to staging database
log "Test 3: Test restore to staging..."
STAGING_DB="staging_dr_test_${TEST_DATE}"
/usr/local/bin/recovery.sh "${LATEST_BACKUP}" "${STAGING_DB}" >> "${TEST_REPORT}" 2>&1
log "✓ Restore to staging completed"

# Test 4: Data validation
log "Test 4: Validating restored data..."
TABLE_COUNT=$(PGPASSWORD="${DB_PASSWORD}" psql \
  -h "${DB_HOST}" \
  -U "${DB_USER}" \
  -d "${STAGING_DB}" \
  -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';")
log "✓ Tables in restored DB: ${TABLE_COUNT}"

# Test 5: Cleanup
log "Test 5: Cleaning up test database..."
PGPASSWORD="${DB_PASSWORD}" psql \
  -h "${DB_HOST}" \
  -U "${DB_USER}" \
  -c "DROP DATABASE ${STAGING_DB};" 2>/dev/null || true
log "✓ Test cleanup completed"

# Generate report
log ""
log "=== DR Test Summary ==="
log "Test Status: PASSED"
log "Duration: $(( $(date +%s) - $(date -d @$(stat -c %Y ${TEST_REPORT}) +%s) )) seconds"
log "Report: ${TEST_REPORT}"

# Send results
aws sns publish \
  --topic-arn "${SNS_TOPIC_ARN}" \
  --subject "✓ Disaster Recovery Test PASSED" \
  --message "DR Test completed successfully

Test ID: ${TEST_DATE}
Latest Backup: $(basename ${LATEST_BACKUP})
Restored Tables: ${TABLE_COUNT}
Report: ${TEST_REPORT}
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

rm -rf "${TEST_DIR}"
```

### Quarterly DR Drill Playbook

```yaml
---
- name: Quarterly Disaster Recovery Drill
  hosts: localhost
  gather_facts: yes

  tasks:
    - name: Announce drill start
      debug:
        msg: |
          🔴 DISASTER RECOVERY DRILL STARTED
          Date: {{ ansible_date_time.iso8601 }}
          Duration: ~2 hours
          Participants: DevOps, Engineering, Operations

    - name: Create test environment
      block:
        - name: Create staging database from latest backup
          command: /usr/local/bin/recovery.sh {{ latest_backup }} dr_drill_{{ ansible_date_time.date }}
          register: recovery_result

        - name: Deploy test application
          kubernetes.core.k8s:
            state: present
            definition: "{{ lookup('template', 'dr-test-deployment.yaml.j2') }}"

        - name: Run smoke tests
          command: /opt/tests/smoke-tests.sh
          register: smoke_tests

    - name: Failover tests
      block:
        - name: Simulate primary region failure
          debug:
            msg: "Simulating primary region outage..."

        - name: Trigger automatic failover
          command: /usr/local/bin/failover.sh
          register: failover_result

        - name: Verify failover success
          assert:
            that:
              - failover_result.rc == 0
              - "'successfully' in failover_result.stdout"

    - name: Cleanup test environment
      kubernetes.core.k8s:
        state: absent
        definition: "{{ lookup('template', 'dr-test-deployment.yaml.j2') }}"

    - name: Generate report
      template:
        src: dr-drill-report.j2
        dest: /var/reports/dr-drill-{{ ansible_date_time.date }}.html

    - name: Send completion notification
      sns:
        msg: |
          DR Drill completed successfully!
          
          Results:
          - Recovery RTO: {{ recovery_result.duration }}s
          - Failover RTO: {{ failover_result.duration }}s
          - Smoke Tests: PASSED
          
          Report: /var/reports/dr-drill-{{ ansible_date_time.date }}.html
        subject: "✓ Quarterly DR Drill Complete"
```

## Incident Response

### RTO/RPO SLA Dashboard

```yaml
# Prometheus metrics for RTO/RPO tracking
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-dr-rules
  namespace: monitoring
data:
  dr-rules.yaml: |
    groups:
    - name: disaster_recovery
      interval: 30s
      rules:
        - alert: BackupMissed
          expr: time() - backup_last_timestamp > 3600
          for: 5m
          labels:
            severity: critical
            rpo_impact: true
          annotations:
            summary: "Backup missed - RPO at risk"

        - alert: ReplicationLagCritical
          expr: replication_lag_seconds > 300
          for: 2m
          labels:
            severity: critical
            rpo_impact: true
          annotations:
            summary: "Replication lag exceeds 5 minutes"

        - alert: PrimaryHealthCheck
          expr: primary_health_check == 0
          for: 30s
          labels:
            severity: critical
            rto_impact: true
          annotations:
            summary: "Primary database health check failed"

        - alert: FailoverCapacityLow
          expr: failover_capacity_percent < 25
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Secondary failover capacity below 25%"
```

## Monitoring & Alerting

### Health Check Automation

```bash
#!/bin/bash
# scripts/health-check.sh

HEALTH_REPORT="/tmp/dr-health-check-$(date +%Y%m%d).json"

check_primary_database() {
  TIMEOUT=5
  response=$(timeout ${TIMEOUT} bash -c "echo > /dev/tcp/${PRIMARY_DB_HOST}/5432" 2>&1)
  if [ $? -eq 0 ]; then
    echo "\"primary_db\": \"UP\""
  else
    echo "\"primary_db\": \"DOWN\""
  fi
}

check_secondary_database() {
  TIMEOUT=5
  response=$(timeout ${TIMEOUT} bash -c "echo > /dev/tcp/${SECONDARY_DB_HOST}/5432" 2>&1)
  if [ $? -eq 0 ]; then
    echo "\"secondary_db\": \"UP\""
  else
    echo "\"secondary_db\": \"DOWN\""
  fi
}

check_replication_lag() {
  LAG=$(PGPASSWORD="${DB_PASSWORD}" psql \
    -h "${PRIMARY_DB_HOST}" \
    -U postgres \
    -t -c "SELECT EXTRACT(EPOCH FROM (now() - pg_last_wal_receive_time())) as lag;" 2>/dev/null)
  echo "\"replication_lag_seconds\": ${LAG:-999}"
}

check_backup_freshness() {
  LATEST_BACKUP=$(ls -t /var/backups/postgresql/full-backup-*.sql.gz 2>/dev/null | head -1)
  if [ -z "${LATEST_BACKUP}" ]; then
    AGE=999999
  else
    BACKUP_TIME=$(stat -c %Y "${LATEST_BACKUP}")
    CURRENT_TIME=$(date +%s)
    AGE=$((CURRENT_TIME - BACKUP_TIME))
  fi
  echo "\"latest_backup_age_seconds\": ${AGE}"
}

# Generate health check report
cat > "${HEALTH_REPORT}" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  $(check_primary_database),
  $(check_secondary_database),
  $(check_replication_lag),
  $(check_backup_freshness),
  "status": "complete"
}
EOF

# Send to monitoring
curl -X POST http://localhost:9091/metrics/job/dr_health_check \
  --data-binary @"${HEALTH_REPORT}"
```

## Documentation

### DR Documentation Template

```markdown
# Disaster Recovery Plan - [Service Name]

## Overview
- **Service**: [Service Name]
- **RTO**: [XX minutes]
- **RPO**: [XX minutes]
- **Last Updated**: [Date]
- **Owner**: [Team Name]

## Recovery Procedures

### Step-by-Step Recovery

1. **Detection** (0-5 min)
   - Monitor alerts
   - Confirm failure
   - Activate war room

2. **Failover** (5-15 min)
   - Promote standby
   - Update DNS
   - Restart applications

3. **Validation** (15-30 min)
   - Run smoke tests
   - Verify connectivity
   - Monitor metrics

## Contacts

| Role | Name | Phone | Email |
|------|------|-------|-------|
| Incident Commander | [Name] | [Phone] | [Email] |
| Database Lead | [Name] | [Phone] | [Email] |
| Infrastructure Lead | [Name] | [Phone] | [Email] |

## Runbook Commands

```bash
# Check status
/usr/local/bin/health-check.sh

# Initiate failover
/usr/local/bin/failover.sh

# Restore from backup
/usr/local/bin/recovery.sh <backup-file>
```
```

---

## Best Practices Summary

✅ **Do:**
- Test DR procedures regularly (quarterly minimum)
- Document all RTO/RPO targets and actual metrics
- Maintain multiple backup copies in different regions
- Automate failover for critical systems
- Monitor backup completion and integrity
- Keep recovery procedures updated
- Train team members on DR procedures
- Use Infrastructure as Code for reproducible recovery
- Implement health checks and automatic detection
- Archive logs and backups for compliance

❌ **Don't:**
- Rely on manual failover for critical systems
- Skip regular DR testing
- Store backups in same region as primary
- Share database credentials in documentation
- Make DR procedures complex or hard to execute
- Ignore replication lag warnings
- Disable automated backups to save costs
- Use untested recovery procedures in production
- Skip post-incident reviews
- Maintain RTO/RPO targets without verification

---

**Note**: This guide is current as of December 2025 and supports:
- PostgreSQL 15.3+
- MySQL 8.0+
- AWS RDS, Multi-Region deployments
- Kubernetes multi-cluster setups
- Terraform 1.14+
- Ansible 2.20+

For the latest updates and community contributions, refer to the [Enterprise Automation Handbook](https://github.com/diceone/Enterprise-Automation-Handbook).
