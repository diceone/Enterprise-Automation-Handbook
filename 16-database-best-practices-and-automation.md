# Database Best Practices and Automation

Comprehensive guide to database automation, provisioning, backup strategies, and enterprise-grade database management patterns for DevOps engineers.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Core Concepts](#core-concepts)
3. [Database Provisioning](#database-provisioning)
4. [Configuration Management](#configuration-management)
5. [Backup and Recovery](#backup-and-recovery)
6. [High Availability & Replication](#high-availability--replication)
7. [Database Migrations](#database-migrations)
8. [Performance & Optimization](#performance--optimization)
9. [Security](#security)
10. [Monitoring & Observability](#monitoring--observability)
11. [Troubleshooting](#troubleshooting)

## Project Structure

### Recommended Directory Layout

```
infrastructure/
├── databases/
│   ├── terraform/
│   │   ├── modules/
│   │   │   ├── rds/
│   │   │   │   ├── main.tf           # RDS instance definition
│   │   │   │   ├── variables.tf      # Input variables
│   │   │   │   ├── outputs.tf        # Instance details
│   │   │   │   └── README.md
│   │   │   ├── postgresql/
│   │   │   ├── mysql/
│   │   │   ├── mongodb/
│   │   │   └── dynamodb/
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   │   ├── main.tf           # Dev DB config
│   │   │   │   └── terraform.tfvars
│   │   │   ├── staging/
│   │   │   └── production/
│   │   ├── backend.tf
│   │   ├── provider.tf
│   │   └── variables.tf
│   ├── ansible/
│   │   ├── roles/
│   │   │   ├── postgresql/
│   │   │   │   ├── tasks/
│   │   │   │   │   ├── main.yml
│   │   │   │   │   ├── install.yml
│   │   │   │   │   ├── configure.yml
│   │   │   │   │   ├── backup.yml
│   │   │   │   │   └── replication.yml
│   │   │   │   ├── templates/
│   │   │   │   │   ├── postgresql.conf.j2
│   │   │   │   │   ├── pg_hba.conf.j2
│   │   │   │   │   └── backup-script.sh.j2
│   │   │   │   ├── defaults/
│   │   │   │   │   └── main.yml
│   │   │   │   └── handlers/
│   │   │   │       └── main.yml
│   │   │   ├── mysql/
│   │   │   ├── mongodb/
│   │   │   ├── backup/
│   │   │   └── replication/
│   │   ├── playbooks/
│   │   │   ├── database-setup.yml
│   │   │   ├── database-backup.yml
│   │   │   ├── database-restore.yml
│   │   │   ├── replication-setup.yml
│   │   │   └── failover.yml
│   │   ├── inventory/
│   │   │   ├── dev/
│   │   │   ├── staging/
│   │   │   └── production/
│   │   └── group_vars/
│   │       └── databases.yml
│   ├── scripts/
│   │   ├── backup.sh            # Backup automation script
│   │   ├── restore.sh           # Restore automation script
│   │   ├── verify.sh            # Backup verification
│   │   └── replication-check.sh # Replication status
│   ├── kubernetes/
│   │   ├── statefulsets/
│   │   │   ├── postgresql.yaml
│   │   │   ├── mysql.yaml
│   │   │   └── mongodb.yaml
│   │   ├── services/
│   │   ├── storage/
│   │   │   ├── pvc.yaml
│   │   │   └── storageclass.yaml
│   │   └── operators/
│   │       ├── postgresql-operator.yaml
│   │       └── mysql-operator.yaml
│   └── docs/
│       ├── backup-strategy.md
│       ├── recovery-procedures.md
│       ├── replication-setup.md
│       └── troubleshooting.md
```

## Core Concepts

### 1. Database Infrastructure as Code

**Principle**: All database infrastructure must be defined as code and version controlled.

```yaml
# Terraform: RDS Instance Definition
resource "aws_db_instance" "postgresql" {
  identifier           = "production-postgres-${var.environment}"
  engine              = "postgres"
  engine_version      = "15.3"
  instance_class      = "db.r6i.2xlarge"
  allocated_storage   = 100
  storage_encrypted   = true
  
  # Multi-AZ for high availability
  multi_az            = var.environment == "production" ? true : false
  
  # Backup configuration
  backup_retention_period = var.environment == "production" ? 30 : 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  # Performance and monitoring
  performance_insights_enabled    = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Security
  db_subnet_group_name            = aws_db_subnet_group.private.name
  vpc_security_group_ids          = [aws_security_group.database.id]
  publicly_accessible            = false
  skip_final_snapshot            = var.environment != "production"
  final_snapshot_identifier      = "${var.identifier}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # Parameters
  parameter_group_name = aws_db_parameter_group.postgresql.name
  
  # Credentials
  db_name  = var.database_name
  username = var.master_username
  password = random_password.db_password.result
  
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.identifier}-password-${var.environment}"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id      = aws_secretsmanager_secret.db_password.id
  secret_string  = random_password.db_password.result
}
```

### 2. Immutability and Versioning

- Database schemas must be version controlled
- Migration scripts must be idempotent and reversible
- Never modify production databases directly
- All changes tracked through version control

### 3. Environment Parity

Ensure dev/staging/production parity:

```hcl
# variables.tf - Environment-specific configurations
variable "instance_class" {
  type = map(string)
  default = {
    development = "db.t4g.micro"      # Development: small, cost-optimized
    staging     = "db.r6i.large"      # Staging: production-like
    production  = "db.r6i.2xlarge"    # Production: high performance
  }
}

variable "backup_retention_period" {
  type = map(number)
  default = {
    development = 1
    staging     = 7
    production  = 30
  }
}

variable "multi_az" {
  type = map(bool)
  default = {
    development = false
    staging     = true
    production  = true
  }
}
```

## Database Provisioning

### Terraform-Based Database Provisioning

#### PostgreSQL Provisioning

```hcl
# modules/postgresql/main.tf
resource "aws_db_instance" "postgresql" {
  identifier           = var.identifier
  engine              = "postgres"
  engine_version      = var.engine_version
  instance_class      = var.instance_class
  allocated_storage   = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage  # Autoscaling
  
  # Storage optimization
  storage_type        = "gp3"
  iops                = var.iops
  storage_throughput  = 250  # MB/s for gp3
  
  # Backup
  backup_retention_period      = var.backup_retention_period
  backup_window                = var.backup_window
  copy_tags_to_snapshot        = true
  delete_automated_backups     = false
  
  # Replication
  multi_az = var.multi_az
  
  # Network
  db_subnet_group_name    = aws_db_subnet_group.database.name
  publicly_accessible     = false
  vpc_security_group_ids  = var.security_group_ids
  
  # Monitoring
  monitoring_interval             = 60
  monitoring_role_arn            = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = true
  
  # Authentication
  db_name  = var.database_name
  username = var.master_username
  password = var.master_password
  
  # Maintenance
  auto_minor_version_upgrade = true
  maintenance_window         = var.maintenance_window
  
  # Encryption
  storage_encrypted = true
  kms_key_id       = aws_kms_key.database.arn
  
  skip_final_snapshot = var.skip_final_snapshot
  
  tags = var.tags
}

# Parameter group for optimization
resource "aws_db_parameter_group" "postgresql" {
  family      = "postgres${var.postgres_family}"
  name        = "${var.identifier}-pg"
  description = "Custom parameter group for ${var.identifier}"

  # Performance tuning
  parameter {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/4}"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "effective_cache_size"
    value = "{DBInstanceClassMemory/4}"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "max_connections"
    value = "500"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "work_mem"
    value = "1048576"  # 1GB in KB
    apply_method = "immediate"
  }

  parameter {
    name  = "maintenance_work_mem"
    value = "2097152"  # 2GB in KB
    apply_method = "immediate"
  }

  # Logging
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries > 1 second
    apply_method = "immediate"
  }

  parameter {
    name  = "log_statement"
    value = "all"
    apply_method = "immediate"
  }

  tags = var.tags
}

# Subnet group (multi-AZ requirement)
resource "aws_db_subnet_group" "database" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = var.tags
}

output "endpoint" {
  value       = aws_db_instance.postgresql.endpoint
  description = "Database endpoint"
}

output "port" {
  value       = aws_db_instance.postgresql.port
  description = "Database port"
}

output "name" {
  value       = aws_db_instance.postgresql.db_name
  description = "Database name"
}
```

#### MySQL Provisioning

```hcl
# modules/mysql/main.tf
resource "aws_db_instance" "mysql" {
  identifier           = var.identifier
  engine              = "mysql"
  engine_version      = var.engine_version
  instance_class      = var.instance_class
  allocated_storage   = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  
  storage_type        = "gp3"
  iops                = var.iops
  storage_throughput  = 250
  
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  multi_az              = var.multi_az
  
  db_subnet_group_name    = aws_db_subnet_group.database.name
  vpc_security_group_ids  = var.security_group_ids
  publicly_accessible     = false
  
  db_name  = var.database_name
  username = var.master_username
  password = var.master_password
  
  parameter_group_name = aws_db_parameter_group.mysql.name
  
  storage_encrypted = true
  kms_key_id       = aws_kms_key.database.arn
  
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  
  skip_final_snapshot = var.skip_final_snapshot
  
  tags = var.tags
}

resource "aws_db_parameter_group" "mysql" {
  family      = "mysql${var.mysql_family}"
  name        = "${var.identifier}-pg"

  # InnoDB optimization
  parameter {
    name  = "innodb_buffer_pool_size"
    value = "{DBInstanceClassMemory*3/4}"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "innodb_log_file_size"
    value = "512M"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "max_connections"
    value = "500"
    apply_method = "immediate"
  }

  # Slow query log
  parameter {
    name  = "slow_query_log"
    value = "1"
    apply_method = "immediate"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
    apply_method = "immediate"
  }

  tags = var.tags
}
```

### Ansible-Based Database Configuration

#### PostgreSQL Setup Playbook

```yaml
# roles/postgresql/tasks/main.yml
---
- name: Include OS-specific variables
  include_vars: "{{ ansible_os_family }}.yml"

- name: Install PostgreSQL packages
  package:
    name: "{{ postgresql_packages }}"
    state: present
  register: postgres_install

- name: Initialize PostgreSQL database
  command: "{{ postgres_initdb_cmd }}"
  environment:
    PGSETUP_INITDB_OPTIONS: "-c shared_buffers=256MB -c max_connections=500"
  when: postgres_install.changed

- name: Enable and start PostgreSQL service
  systemd:
    name: postgresql
    enabled: yes
    state: started
    daemon_reload: yes

- name: Create PostgreSQL backup directory
  file:
    path: /var/lib/pgsql/backups
    state: directory
    owner: postgres
    group: postgres
    mode: '0700'

- name: Configure PostgreSQL
  include_tasks: configure.yml

- name: Setup replication
  include_tasks: replication.yml
  when: enable_replication | default(false)

- name: Setup backup scripts
  include_tasks: backup.yml

- name: Verify PostgreSQL connectivity
  command: "{{ verify_postgres_cmd }}"
  register: postgres_check
  failed_when: postgres_check.rc != 0
```

#### PostgreSQL Configuration

```yaml
# roles/postgresql/tasks/configure.yml
---
- name: Configure postgresql.conf
  template:
    src: postgresql.conf.j2
    dest: /etc/postgresql/{{ postgres_version }}/main/postgresql.conf
    owner: postgres
    group: postgres
    mode: '0644'
    backup: yes
  notify: restart postgresql

- name: Configure pg_hba.conf
  template:
    src: pg_hba.conf.j2
    dest: /etc/postgresql/{{ postgres_version }}/main/pg_hba.conf
    owner: postgres
    group: postgres
    mode: '0640'
    backup: yes
  notify: restart postgresql

- name: Create PostgreSQL users
  postgresql_user:
    name: "{{ item.name }}"
    password: "{{ item.password }}"
    role_attr_flags: "{{ item.role_attr_flags | default('') }}"
    state: present
  loop: "{{ postgres_users }}"
  no_log: yes

- name: Create PostgreSQL databases
  postgresql_db:
    name: "{{ item.name }}"
    owner: "{{ item.owner }}"
    template: template0
    state: present
  loop: "{{ postgres_databases }}"

- name: Grant database privileges
  postgresql_privs:
    db: "{{ item.db }}"
    role: "{{ item.role }}"
    objs: "{{ item.objs }}"
    privs: "{{ item.privs }}"
    type: "{{ item.type | default('database') }}"
  loop: "{{ postgres_privileges }}"
```

#### PostgreSQL Replication Setup

```yaml
# roles/postgresql/tasks/replication.yml
---
- name: Create replication user
  postgresql_user:
    name: replicator
    password: "{{ replication_password }}"
    role_attr_flags: REPLICATION
    state: present
  no_log: yes
  when: postgres_role == 'primary'

- name: Configure primary for replication
  block:
    - name: Update postgresql.conf for primary
      lineinfile:
        path: /etc/postgresql/{{ postgres_version }}/main/postgresql.conf
        regexp: "{{ item.regexp }}"
        line: "{{ item.line }}"
        state: present
      loop:
        - { regexp: '^wal_level', line: 'wal_level = replica' }
        - { regexp: '^max_wal_senders', line: 'max_wal_senders = 10' }
        - { regexp: '^max_replication_slots', line: 'max_replication_slots = 10' }
        - { regexp: '^hot_standby_feedback', line: 'hot_standby_feedback = on' }
      notify: restart postgresql

    - name: Add standby server to pg_hba.conf
      lineinfile:
        path: /etc/postgresql/{{ postgres_version }}/main/pg_hba.conf
        line: "host replication replicator {{ standby_ip }}/32 md5"
        state: present
      notify: restart postgresql
  when: postgres_role == 'primary'

- name: Configure standby for replication
  block:
    - name: Stop PostgreSQL on standby
      systemd:
        name: postgresql
        state: stopped

    - name: Remove standby data directory
      file:
        path: /var/lib/postgresql/{{ postgres_version }}/main
        state: absent

    - name: Create base backup from primary
      command: |
        pg_basebackup -h {{ primary_host }} -U replicator -D /var/lib/postgresql/{{ postgres_version }}/main -Fp -Xs -P -R
      become_user: postgres
      environment:
        PGPASSWORD: "{{ replication_password }}"

    - name: Update recovery.conf on standby
      lineinfile:
        path: /var/lib/postgresql/{{ postgres_version }}/main/recovery.conf
        line: "{{ item }}"
        create: yes
        owner: postgres
        group: postgres
        mode: '0600'
      loop:
        - "standby_mode = 'on'"
        - "primary_conninfo = 'host={{ primary_host }} port=5432 user=replicator password={{ replication_password }}'"

    - name: Start PostgreSQL on standby
      systemd:
        name: postgresql
        state: started
  when: postgres_role == 'standby'
```

## Configuration Management

### Database Parameter Optimization

#### PostgreSQL Parameter Groups

```yaml
# roles/postgresql/defaults/main.yml
---
postgres_version: "15"
postgres_packages:
  - postgresql-15
  - postgresql-contrib-15
  - postgresql-client-15

# Performance tuning
postgres_params:
  shared_buffers: "256MB"  # 25% of system memory
  effective_cache_size: "1GB"  # 75% of system memory
  maintenance_work_mem: "64MB"
  work_mem: "10MB"
  max_connections: "500"
  max_parallel_workers: "8"
  wal_buffers: "16MB"

# WAL (Write-Ahead Logging) configuration
postgres_wal_params:
  wal_level: "replica"
  max_wal_senders: "10"
  wal_keep_size: "2GB"
  wal_compression: "on"

# Connection settings
postgres_connection_params:
  listen_addresses: "*"
  unix_socket_directories: "/var/run/postgresql"
  tcp_keepalives_idle: "30"
  tcp_keepalives_interval: "30"

# Logging configuration
postgres_logging_params:
  log_min_duration_statement: "1000"  # Log queries > 1 second
  log_statement: "all"
  log_duration: "off"
  log_checkpoints: "on"
  log_connections: "on"
  log_disconnections: "on"
  log_lock_waits: "on"
```

#### MySQL Parameter Groups

```yaml
# roles/mysql/defaults/main.yml
---
mysql_version: "8.0"
mysql_packages:
  - mysql-server-8.0
  - mysql-client-8.0

# InnoDB settings (primary storage engine)
mysql_params:
  innodb_buffer_pool_size: "768M"  # 75% of system memory
  innodb_log_file_size: "256M"
  innodb_flush_log_at_trx_commit: "1"  # Full ACID compliance
  innodb_flush_method: "O_DIRECT"

# Performance tuning
mysql_performance_params:
  max_connections: "500"
  max_allowed_packet: "64M"
  query_cache_size: "0"  # Disabled in MySQL 8.0+
  tmp_table_size: "32M"
  max_heap_table_size: "32M"

# Slow query log
mysql_logging_params:
  slow_query_log: "1"
  slow_query_log_file: "/var/log/mysql/slow.log"
  long_query_time: "2"
  log_queries_not_using_indexes: "1"
```

### Database User Management

```yaml
# roles/postgresql/tasks/configure.yml - User management
---
- name: Create application database users
  postgresql_user:
    name: "{{ item.username }}"
    password: "{{ item.password }}"
    role_attr_flags: "{{ item.flags | default('') }}"
    state: present
  loop:
    - { username: "app_user", password: "{{ app_password }}", flags: "" }
    - { username: "backup_user", password: "{{ backup_password }}", flags: "" }
    - { username: "replicator", password: "{{ replication_password }}", flags: "REPLICATION" }
  no_log: yes

- name: Create production databases
  postgresql_db:
    name: "{{ item }}"
    owner: "app_user"
    encoding: "UTF8"
    lc_collate: "en_US.UTF-8"
    lc_ctype: "en_US.UTF-8"
    template: "template0"
    state: present
  loop:
    - "production_db"
    - "analytics_db"

- name: Grant schema privileges
  postgresql_privs:
    db: "production_db"
    privs: "ALL"
    type: "schema"
    objs: "public"
    role: "app_user"
```

## Backup and Recovery

### Automated Backup Strategy

#### Backup Architecture

```bash
# scripts/backup.sh
#!/bin/bash
set -e

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-backup_user}"
DB_NAME="${DB_NAME:-production}"
BACKUP_DIR="/var/backups/postgresql"
S3_BUCKET="company-database-backups"
RETENTION_DAYS=30

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Full backup
BACKUP_FILE="${BACKUP_DIR}/full-backup-$(date +%Y%m%d-%H%M%S).sql.gz"
echo "Starting full backup: ${BACKUP_FILE}"

PGPASSWORD="${DB_PASSWORD}" pg_dump \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d "${DB_NAME}" \
  --verbose \
  --compress=9 \
  --jobs=4 \
  --quote-all-identifiers \
  > "${BACKUP_FILE}"

if [ $? -eq 0 ]; then
  echo "✓ Backup completed successfully"
  
  # Calculate file size
  SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
  echo "Backup size: ${SIZE}"
  
  # Upload to S3
  echo "Uploading to S3..."
  aws s3 cp "${BACKUP_FILE}" \
    "s3://${S3_BUCKET}/postgresql/$(date +%Y/%m/%d)/" \
    --storage-class GLACIER_IR \
    --sse AES256 \
    --metadata "host=${DB_HOST},database=${DB_NAME},timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  if [ $? -eq 0 ]; then
    echo "✓ Backup uploaded to S3"
    
    # Cleanup old backups (local)
    find "${BACKUP_DIR}" -name "full-backup-*.sql.gz" -mtime +3 -delete
    echo "✓ Old local backups cleaned"
  else
    echo "✗ S3 upload failed"
    exit 1
  fi
else
  echo "✗ Backup failed"
  exit 1
fi

# Send notification
BACKUP_STATUS="SUCCESS"
BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
aws sns publish \
  --topic-arn "arn:aws:sns:us-east-1:123456789:db-backups" \
  --subject "Database Backup ${BACKUP_STATUS}: ${DB_NAME}" \
  --message "Backup: ${BACKUP_FILE}
Size: ${BACKUP_SIZE}
Host: ${DB_HOST}
Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

#### Incremental Backup with WAL Archiving

```yaml
# roles/postgresql/tasks/backup.yml
---
- name: Create WAL archive directory
  file:
    path: /var/lib/pgsql/wal_archive
    state: directory
    owner: postgres
    group: postgres
    mode: '0700'

- name: Configure WAL archiving
  lineinfile:
    path: /etc/postgresql/{{ postgres_version }}/main/postgresql.conf
    regexp: "^archive_command"
    line: "archive_command = 'test ! -f /var/lib/pgsql/wal_archive/%f && cp %p /var/lib/pgsql/wal_archive/%f'"
    state: present
  notify: restart postgresql

- name: Setup WAL archiving to S3
  template:
    src: wal-archive-s3.sh.j2
    dest: /usr/local/bin/wal-archive-s3.sh
    owner: root
    group: root
    mode: '0755'

- name: Deploy backup script
  template:
    src: backup-script.sh.j2
    dest: /usr/local/bin/backup-postgresql.sh
    owner: root
    group: root
    mode: '0755'

- name: Create backup cron job
  cron:
    name: "PostgreSQL full backup"
    user: root
    hour: "2"
    minute: "0"
    job: "/usr/local/bin/backup-postgresql.sh >> /var/log/postgresql/backup.log 2>&1"
    state: present
```

### Restore Procedures

#### PostgreSQL Restore Strategy

```bash
# scripts/restore.sh
#!/bin/bash
set -e

RESTORE_FILE="${1:-}"
TARGET_DB="${2:-restored_db}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-backup_user}"

if [ -z "${RESTORE_FILE}" ]; then
  echo "Usage: $0 <backup-file> [target-database]"
  exit 1
fi

if [ ! -f "${RESTORE_FILE}" ]; then
  echo "Error: Backup file not found: ${RESTORE_FILE}"
  exit 1
fi

echo "Starting restore from: ${RESTORE_FILE}"
echo "Target database: ${TARGET_DB}"

# Create restore log
RESTORE_LOG="/var/log/postgresql/restore-$(date +%Y%m%d-%H%M%S).log"

# Create target database if it doesn't exist
PGPASSWORD="${DB_PASSWORD}" psql \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -c "CREATE DATABASE ${TARGET_DB};" 2>/dev/null || true

# Perform restore
echo "Restoring data..."
gunzip -c "${RESTORE_FILE}" | \
  PGPASSWORD="${DB_PASSWORD}" psql \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -U "${DB_USER}" \
    -d "${TARGET_DB}" \
    --verbose \
    2>&1 | tee "${RESTORE_LOG}"

if [ ${PIPESTATUS[1]} -eq 0 ]; then
  echo "✓ Restore completed successfully"
  echo "Log: ${RESTORE_LOG}"
else
  echo "✗ Restore failed"
  echo "Log: ${RESTORE_LOG}"
  exit 1
fi

# Verify restore
echo "Verifying restore..."
PGPASSWORD="${DB_PASSWORD}" psql \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d "${TARGET_DB}" \
  -c "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='public';"
```

### Point-in-Time Recovery (PITR)

```yaml
# Kubernetes job for PITR
apiVersion: batch/v1
kind: Job
metadata:
  name: postgresql-pitr
  namespace: databases
spec:
  template:
    spec:
      serviceAccountName: postgresql
      containers:
      - name: pitr-restore
        image: postgres:15
        env:
        - name: RESTORE_TIME
          value: "2024-12-01T14:30:00Z"  # Target time
        - name: SOURCE_BACKUP
          value: "s3://company-backups/postgresql/full-backup-20241201-120000.sql.gz"
        command:
        - /bin/bash
        - -c
        - |
          # Download base backup
          aws s3 cp $SOURCE_BACKUP - | gunzip | psql -d $TARGET_DB
          
          # Restore WAL files up to target time
          for wal_file in $(aws s3 ls s3://company-backups/wal/ --recursive | grep 2024-12-01 | awk '{print $4}'); do
            aws s3 cp "s3://$wal_file" /pg_wal/
          done
          
          # Restore to point in time
          echo "recovery_target_timeline = 'latest'" >> postgresql.conf
          echo "recovery_target_xid = '$TARGET_XID'" >> postgresql.conf
          echo "recovery_target = 'immediate'" >> postgresql.conf
      restartPolicy: Never
  backoffLimit: 3
```

## High Availability & Replication

### PostgreSQL Streaming Replication

```yaml
# Ansible playbook for setting up streaming replication
---
- name: Setup PostgreSQL streaming replication
  hosts: all
  become: yes
  vars:
    primary_host: "db-primary.internal"
    standby_hosts:
      - "db-standby-1.internal"
      - "db-standby-2.internal"

  tasks:
    - name: Configure primary server
      block:
        - name: Update postgresql.conf
          lineinfile:
            path: /etc/postgresql/15/main/postgresql.conf
            regexp: "{{ item.regexp }}"
            line: "{{ item.line }}"
            state: present
          loop:
            - { regexp: '^wal_level', line: 'wal_level = replica' }
            - { regexp: '^max_wal_senders', line: 'max_wal_senders = 3' }
            - { regexp: '^max_replication_slots', line: 'max_replication_slots = 3' }
            - { regexp: '^synchronous_commit', line: 'synchronous_commit = remote_apply' }
          notify: restart postgresql

        - name: Configure pg_hba.conf for standby access
          lineinfile:
            path: /etc/postgresql/15/main/pg_hba.conf
            line: "host replication replicator {{ item }}/32 scram-sha-256"
            state: present
          loop: "{{ standby_hosts }}"
          notify: restart postgresql

      when: inventory_hostname == primary_host

    - name: Configure standby servers
      block:
        - name: Stop PostgreSQL
          systemd:
            name: postgresql
            state: stopped

        - name: Backup primary data
          command: |
            pg_basebackup -h {{ primary_host }} -U replicator \
            -D /var/lib/postgresql/15/main -Fp -Xs -P -R -W
          environment:
            PGPASSWORD: "{{ replication_password }}"
          become_user: postgres

        - name: Start PostgreSQL on standby
          systemd:
            name: postgresql
            state: started

      when: inventory_hostname in standby_hosts
```

### MySQL Replication Setup

```yaml
# Ansible playbook for MySQL replication
---
- name: Setup MySQL master-slave replication
  hosts: all
  become: yes

  tasks:
    - name: Configure MySQL master
      block:
        - name: Update MySQL configuration
          lineinfile:
            path: /etc/mysql/mysql.conf.d/mysqld.cnf
            regexp: "{{ item.regexp }}"
            line: "{{ item.line }}"
            state: present
          loop:
            - { regexp: '^server-id', line: 'server-id = 1' }
            - { regexp: '^log_bin', line: 'log_bin = /var/log/mysql/mysql-bin.log' }
            - { regexp: '^binlog_format', line: 'binlog_format = ROW' }
            - { regexp: '^binlog_row_image', line: 'binlog_row_image = FULL' }
          notify: restart mysql

        - name: Create replication user
          mysql_user:
            name: replicator
            password: "{{ replication_password }}"
            priv: "*.*:REPLICATION SLAVE"
            state: present
          no_log: yes

      when: inventory_hostname == "mysql-master"

    - name: Configure MySQL slave
      block:
        - name: Get master binary log file and position
          mysql_query:
            login_user: root
            query: "SHOW MASTER STATUS"
          register: master_status
          delegate_to: "mysql-master"

        - name: Update MySQL slave configuration
          lineinfile:
            path: /etc/mysql/mysql.conf.d/mysqld.cnf
            regexp: "{{ item.regexp }}"
            line: "{{ item.line }}"
            state: present
          loop:
            - { regexp: '^server-id', line: 'server-id = 2' }
            - { regexp: '^relay-log', line: 'relay-log = /var/log/mysql/mysql-relay-bin' }
          notify: restart mysql

        - name: Configure replication
          mysql_query:
            login_user: root
            query: |
              CHANGE MASTER TO
              MASTER_HOST='{{ master_host }}',
              MASTER_USER='replicator',
              MASTER_PASSWORD='{{ replication_password }}',
              MASTER_LOG_FILE='{{ master_status.query_result[0][0].File }}',
              MASTER_LOG_POS={{ master_status.query_result[0][0].Position }};
              START SLAVE;
          no_log: yes

      when: inventory_hostname == "mysql-slave"
```

## Database Migrations

### Schema Migration Strategy

#### Migration File Structure

```
migrations/
├── 001_initial_schema.sql
├── 002_add_users_table.sql
├── 003_add_indexes.sql
├── 004_add_constraints.sql
└── README.md
```

#### Migration Management with Flyway

```yaml
# Ansible playbook for database migrations
---
- name: Deploy database migrations
  hosts: databases
  become: yes

  tasks:
    - name: Install Flyway
      unarchive:
        src: "https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/9.22.3/flyway-commandline-9.22.3-linux-x64.tar.gz"
        dest: /opt/
        remote_src: yes
        creates: /opt/flyway/flyway

    - name: Create Flyway configuration
      template:
        src: flyway.conf.j2
        dest: /opt/flyway/conf/flyway.conf
        owner: root
        group: root
        mode: '0644'
      vars:
        db_url: "jdbc:postgresql://localhost:5432/{{ database_name }}"
        db_user: "{{ migration_user }}"
        db_password: "{{ migration_password }}"

    - name: Copy migration files
      copy:
        src: migrations/
        dest: /opt/flyway/sql/
        owner: root
        group: root
        mode: '0644'

    - name: Execute migrations
      shell: /opt/flyway/flyway -configFiles=/opt/flyway/conf/flyway.conf migrate
      register: migration_result
      failed_when: "'FAILED' in migration_result.stdout or migration_result.rc != 0"

    - name: Display migration results
      debug:
        var: migration_result.stdout_lines

    - name: Verify migration schema
      postgresql_query:
        db: "{{ database_name }}"
        query: "SELECT version, description, installed_on FROM flyway_schema_history ORDER BY installed_on DESC LIMIT 5;"
      register: migration_history

    - name: Show migration history
      debug:
        var: migration_history.query_result
```

#### Migration Script Example

```sql
-- migrations/001_initial_schema.sql
-- Idempotent migration with rollback support

-- Forward migration
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Metadata tables for rollback tracking
CREATE TABLE IF NOT EXISTS schema_migrations (
    id SERIAL PRIMARY KEY,
    version INT NOT NULL UNIQUE,
    description VARCHAR(255),
    type VARCHAR(20),
    installed_by VARCHAR(100),
    installed_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_time INT,
    success BOOLEAN
);
```

## Performance & Optimization

### Query Optimization

```yaml
# Ansible playbook for performance analysis
---
- name: PostgreSQL query optimization
  hosts: databases
  become_user: postgres

  tasks:
    - name: Analyze query performance
      postgresql_query:
        db: production
        query: |
          SELECT 
            query, 
            calls, 
            total_time, 
            mean_time 
          FROM pg_stat_statements 
          WHERE mean_time > 100 
          ORDER BY mean_time DESC LIMIT 10;
      register: slow_queries

    - name: Create indexes for optimization
      postgresql_query:
        db: production
        query: |
          CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_user_id 
          ON orders(user_id);
          
          CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_created_at 
          ON orders(created_at DESC);

    - name: Analyze table statistics
      postgresql_query:
        db: production
        query: "ANALYZE orders;"

    - name: Vacuum analyze
      postgresql_query:
        db: production
        query: "VACUUM ANALYZE orders;"
```

### Connection Pooling

```yaml
# PgBouncer configuration for connection pooling
---
- name: Deploy PgBouncer connection pool
  hosts: databases
  become: yes

  tasks:
    - name: Install PgBouncer
      package:
        name: pgbouncer
        state: present

    - name: Configure PgBouncer
      template:
        src: pgbouncer.ini.j2
        dest: /etc/pgbouncer/pgbouncer.ini
        owner: pgbouncer
        group: pgbouncer
        mode: '0600'
      vars:
        pool_mode: "transaction"
        max_client_conn: "1000"
        default_pool_size: "25"
        min_pool_size: "10"

    - name: Enable and start PgBouncer
      systemd:
        name: pgbouncer
        enabled: yes
        state: started
```

## Security

### Database Encryption

```hcl
# Terraform configuration for encrypted database
resource "aws_kms_key" "database" {
  description             = "KMS key for database encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_kms_alias" "database" {
  name          = "alias/database-${var.environment}"
  target_key_id = aws_kms_key.database.key_id
}

resource "aws_db_instance" "encrypted" {
  # ... other configuration ...
  
  storage_encrypted = true
  kms_key_id       = aws_kms_key.database.arn
  
  # Enable encryption in transit
  db_parameter_group_name = aws_db_parameter_group.encrypted.name
}

# Enable SSL/TLS
resource "aws_db_parameter_group" "encrypted" {
  family = "postgres15"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}
```

### Access Control

```yaml
# Role-based access control
---
- name: Setup database access control
  hosts: databases
  become_user: postgres

  tasks:
    - name: Create application role
      postgresql_user:
        name: app_user
        password: "{{ app_password }}"
        state: present
      no_log: yes

    - name: Create read-only role
      postgresql_user:
        name: readonly_user
        password: "{{ readonly_password }}"
        state: present
      no_log: yes

    - name: Grant appropriate privileges
      postgresql_privs:
        db: production
        role: "{{ item.role }}"
        privs: "{{ item.privs }}"
        type: "{{ item.type }}"
        objs: "{{ item.objs }}"
      loop:
        - { role: "app_user", privs: "ALL", type: "schema", objs: "public" }
        - { role: "readonly_user", privs: "SELECT", type: "schema", objs: "public" }
        - { role: "readonly_user", privs: "USAGE", type: "schema", objs: "public" }
```

## Monitoring & Observability

### Database Monitoring Stack

```yaml
# Kubernetes deployment for database monitoring
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgresql-exporter-config
  namespace: monitoring
data:
  queries.yaml: |
    pg_up:
      query: "SELECT 1"
      metrics:
      - pg_up:
          usage: "GAUGE"
          description: "PostgreSQL is up (1 = yes, 0 = no)"
    
    pg_connections:
      query: "SELECT count(*) as connection_count FROM pg_stat_activity"
      metrics:
      - pg_connections:
          usage: "GAUGE"
          description: "Number of active connections"

    pg_cache_hit_ratio:
      query: |
        SELECT 
          CASE WHEN sum(heap_blks_hit) + sum(heap_blks_read) = 0 THEN 0
          ELSE sum(heap_blks_hit)::FLOAT / (sum(heap_blks_hit) + sum(heap_blks_read))
          END as cache_hit_ratio
        FROM pg_statio_user_tables
      metrics:
      - pg_cache_hit_ratio:
          usage: "GAUGE"
          description: "Database cache hit ratio"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql-exporter
  template:
    metadata:
      labels:
        app: postgresql-exporter
    spec:
      containers:
      - name: exporter
        image: prometheuscommunity/postgres-exporter:v0.12.0
        env:
        - name: DATA_SOURCE_NAME
          valueFrom:
            secretKeyRef:
              name: postgresql-credentials
              key: dsn
        - name: PG_EXPORTER_EXTEND_QUERY_PATH
          value: /config/queries.yaml
        ports:
        - containerPort: 9187
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        configMap:
          name: postgresql-exporter-config

---
apiVersion: v1
kind: Service
metadata:
  name: postgresql-exporter
  namespace: monitoring
spec:
  selector:
    app: postgresql-exporter
  ports:
  - port: 9187
    targetPort: 9187
```

### Prometheus Alerting Rules

```yaml
# Prometheus alert rules for databases
groups:
- name: database.rules
  interval: 30s
  rules:
    - alert: DatabaseConnectionHigh
      expr: pg_connections > 400
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High database connections: {{ $value }}"

    - alert: DatabaseCacheHitRatioLow
      expr: pg_cache_hit_ratio < 0.90
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Low cache hit ratio: {{ $value | humanizePercentage }}"

    - alert: DatabaseReplicationLag
      expr: pg_replication_lag_seconds > 10
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Database replication lag: {{ $value }}s"

    - alert: DatabaseBackupMissing
      expr: time() - db_last_backup_timestamp > 86400
      for: 1h
      labels:
        severity: critical
      annotations:
        summary: "Database backup is overdue"

    - alert: DiskUsageHigh
      expr: db_disk_usage_percent > 85
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Database disk usage: {{ $value }}%"
```

## Troubleshooting

### Common Database Issues and Solutions

| Issue | Cause | Solution | Prevention |
|-------|-------|----------|-----------|
| Connection Timeouts | Connection pool exhaustion | Increase pool size, terminate idle connections | Monitor connections, use connection pooling |
| Slow Queries | Missing indexes, suboptimal query plans | Run EXPLAIN ANALYZE, add indexes | Regular query analysis, code review |
| High CPU Usage | Inefficient queries, missing indexes | Identify slow queries, optimize queries | Query monitoring, load testing |
| Replication Lag | Network latency, high write volume | Monitor lag, adjust synchronous_commit | Network optimization, capacity planning |
| Out of Disk Space | Excessive logging, large tables | Archive old data, increase storage | Monitor disk usage, implement retention |
| Backup Failures | Storage issues, insufficient permissions | Check backup logs, verify permissions | Regular backup testing, automated alerts |
| Deadlocks | Transaction conflicts | Review transaction logic, add timeouts | Code review, transaction analysis |
| Memory Pressure | Undersized cache, too many connections | Increase shared_buffers, limit connections | Capacity planning, load testing |

### Troubleshooting Commands

```bash
# PostgreSQL diagnostics
psql -c "SELECT version();"
psql -c "SELECT * FROM pg_stat_activity;"
psql -c "SELECT * FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
psql -c "SELECT * FROM pg_stat_replication;"

# MySQL diagnostics
mysql -e "SHOW STATUS LIKE 'Threads%';"
mysql -e "SHOW PROCESSLIST;"
mysql -e "SHOW SLAVE STATUS\G"

# Check replication status
psql -c "SELECT slot_name, slot_type, restart_lsn, confirmed_flush_lsn FROM pg_replication_slots;"

# Monitor WAL archiving
ls -lh /var/lib/pgsql/wal_archive/ | tail -20

# Check backup integrity
pg_restore --list /path/to/backup.sql.gz | head -20
```

---

## Best Practices Summary

✅ **Do:**
- Use Infrastructure as Code for all databases
- Implement automated, tested backup and recovery procedures
- Monitor all database metrics in real-time
- Use connection pooling for efficient resource usage
- Encrypt data at rest and in transit
- Implement role-based access control
- Version control all database schemas and migrations
- Test failover and recovery procedures regularly
- Use read replicas for high availability
- Archive logs and backups for compliance

❌ **Don't:**
- Make direct database modifications without version control
- Skip backup testing and verification
- Use weak passwords or shared credentials
- Mix structured and unstructured logging
- Deploy without monitoring and alerting
- Use production data in development/testing
- Skip capacity planning and performance testing
- Modify database settings without documentation
- Ignore replication lag and monitoring
- Deploy schema changes without testing

---

**Note**: This guide is current as of December 2025 and supports:
- PostgreSQL 15.3+
- MySQL 8.0+
- MongoDB 6.0+
- AWS RDS, GCP Cloud SQL, Azure Database services
- Ansible 2.20+, Terraform 1.14+, Kubernetes 1.34+

For the latest updates and community contributions, refer to the [Enterprise Automation Handbook](https://github.com/diceone/Enterprise-Automation-Handbook).
