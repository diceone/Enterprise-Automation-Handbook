# DevSecOps Guidelines and Principles

Comprehensive guide for integrating security into DevOps practices, covering secure infrastructure automation, vulnerability management, compliance, and incident response for enterprise environments.

## Table of Contents

1. [Core DevSecOps Principles](#core-devsecops-principles)
2. [Secrets Management](#secrets-management)
3. [Infrastructure Security](#infrastructure-security)
4. [Container Security](#container-security)
5. [Supply Chain Security](#supply-chain-security)
6. [Code Security](#code-security)
7. [Network Security](#network-security)
8. [Compliance and Audit](#compliance-and-audit)
9. [Incident Response](#incident-response)
10. [Security Automation](#security-automation)

---

## Core DevSecOps Principles

DevSecOps integrates security throughout the entire software development and infrastructure lifecycle—from planning and development through deployment and operations.

### 1. Shift-Left Security

Move security checks earlier in the development lifecycle to catch vulnerabilities before they reach production.

**❌ BAD - Security only at end:**
```
Code → Build → Test → Deploy → Production (SECURITY CHECK HERE)
       ↑         ↑       ↑         ↑
    No checks  No checks No checks Late detection
```

**✅ GOOD - Security throughout:**
```
Planning → Code → Build → Test → Deploy → Production
   ↓         ↓      ↓       ↓       ↓        ↓
   📋        🔐     🔐      🔐      🔐       🔐
Security  SAST   Lint  DAST   Sec    Runtime
Planning  Scan   Rules Scan   Scan   Monitor
```

**Implementation:**
- Static Application Security Testing (SAST) in code commit hooks
- Dependency scanning during build
- Container scanning before deployment
- Infrastructure-as-Code security scanning
- Runtime security monitoring in production

### 2. Security as Code

Treat security policies and configurations as code, version-controlled and reviewable.

**❌ BAD - Manual security management:**
```yaml
# Security rules applied manually
- SSH key rotation: manual process
- Firewall rules: manual update
- IAM policies: manual adjustment
- Compliance checks: manual audit
```

**✅ GOOD - Security as Code:**
```yaml
# security.yml - Version controlled
security_policies:
  ssh:
    key_rotation_days: 90
    required_key_type: ed25519
    
  firewall:
    default_deny: true
    allowed_ports:
      - 443  # HTTPS
      - 22   # SSH (restricted)
      
  iam:
    mfa_required: true
    session_duration: 3600
    
  compliance:
    standards: [PCI-DSS, SOC2, ISO27001]
    audit_frequency: daily
```

### 3. Least Privilege Access

Grant minimum required permissions for each role, service, and process.

**❌ BAD - Excessive permissions:**
```yaml
# IAM Role with over-permissions
- PolicyName: AdminAccess
  PolicyDocument:
    Statement:
      - Effect: Allow
        Action: "*"              # ALL actions!
        Resource: "*"            # ALL resources!
```

**✅ GOOD - Least privilege:**
```yaml
# IAM Role with specific permissions
- PolicyName: ApplicationDeployment
  PolicyDocument:
    Statement:
      - Effect: Allow
        Action:
          - ec2:DescribeInstances
          - ec2:StartInstances
          - ec2:StopInstances
        Resource: "arn:aws:ec2:region:account:instance/app-*"
        
      - Effect: Allow
        Action:
          - s3:GetObject
        Resource: "arn:aws:s3:::app-artifacts/*"
```

### 4. Defense in Depth

Implement multiple security layers; don't rely on a single control.

**Multi-layer security architecture:**
```
┌─────────────────────────────────────────┐
│  Layer 1: Perimeter Security            │ (WAF, DDoS protection)
├─────────────────────────────────────────┤
│  Layer 2: Network Security              │ (VPC, Security Groups, NACLs)
├─────────────────────────────────────────┤
│  Layer 3: Host Security                 │ (OS hardening, antivirus)
├─────────────────────────────────────────┤
│  Layer 4: Application Security          │ (Auth, encryption, input validation)
├─────────────────────────────────────────┤
│  Layer 5: Data Security                 │ (Encryption at rest, encryption in transit)
├─────────────────────────────────────────┤
│  Layer 6: Access Control                │ (RBAC, MFA, audit logging)
├─────────────────────────────────────────┤
│  Layer 7: Monitoring & Response         │ (SIEM, alerting, incident response)
└─────────────────────────────────────────┘
```

### 5. Continuous Monitoring

Monitor security posture continuously, not just at deployment time.

**Implementation:**
- Runtime threat detection
- Configuration drift detection
- Vulnerability scanning
- Access pattern analysis
- Suspicious behavior detection

---

## Secrets Management

Properly handle sensitive data like credentials, API keys, and certificates.

### Principles

**NEVER:**
- ❌ Hardcode secrets in code
- ❌ Store secrets in Git repositories
- ❌ Use generic credentials for all environments
- ❌ Share secrets in chat or emails
- ❌ Log secrets in application output

**ALWAYS:**
- ✅ Use centralized secret management (Vault, AWS Secrets Manager)
- ✅ Rotate secrets regularly
- ✅ Audit secret access
- ✅ Encrypt secrets in transit and at rest
- ✅ Use environment-specific secrets

### Implementation Patterns

**❌ BAD - Secrets in code:**
```python
# application.py
DATABASE_PASSWORD = "prod_password_123"
API_KEY = "sk-1234567890abcdef"
AWS_ACCESS_KEY = "AKIAIOSFODNN7EXAMPLE"

def connect_db():
    conn = psycopg2.connect(
        host="db.example.com",
        password=DATABASE_PASSWORD  # Hardcoded!
    )
```

**✅ GOOD - Centralized secrets:**
```python
# application.py - Retrieve from Vault
import hvac

class SecretManager:
    def __init__(self):
        self.client = hvac.Client(
            url='https://vault.example.com',
            token=os.environ['VAULT_TOKEN']
        )
    
    def get_database_password(self):
        secret = self.client.secrets.kv.read_secret_version(
            path='database/prod/password'
        )
        return secret['data']['data']['password']
    
    def get_api_key(self):
        secret = self.client.secrets.kv.read_secret_version(
            path='api/prod/key'
        )
        return secret['data']['data']['key']

def connect_db():
    secrets = SecretManager()
    password = secrets.get_database_password()
    conn = psycopg2.connect(
        host="db.example.com",
        password=password
    )
```

### Vault Configuration Example

```yaml
# roles/vault_setup/tasks/main.yml
---
- name: Setup HashiCorp Vault
  block:
    - name: Install Vault
      package:
        name: vault
        state: present
    
    - name: Configure Vault for TLS
      copy:
        dest: /etc/vault/config.hcl
        content: |
          storage "consul" {
            address = "localhost:8500"
            path    = "vault"
          }
          
          listener "tcp" {
            address       = "0.0.0.0:8200"
            tls_cert_file = "/etc/vault/certs/vault.crt"
            tls_key_file  = "/etc/vault/certs/vault.key"
          }
          
          ui = true
    
    - name: Start Vault service
      service:
        name: vault
        state: started
        enabled: yes
    
    - name: Unseal Vault
      command: vault operator unseal {{ vault_key_1 }}
      environment:
        VAULT_ADDR: "https://vault.example.com:8200"
      no_log: true

- name: Configure secret engines
  block:
    - name: Enable KV v2 secrets engine
      command: vault secrets enable -path=secret kv-v2
      environment:
        VAULT_ADDR: "https://vault.example.com:8200"
        VAULT_TOKEN: "{{ vault_token }}"
      no_log: true
    
    - name: Create secret policy
      copy:
        dest: /tmp/app-policy.hcl
        content: |
          path "secret/data/app/*" {
            capabilities = ["read", "list"]
          }
          
          path "secret/data/database/*" {
            capabilities = ["read"]
          }
```

---

## Infrastructure Security

Secure infrastructure-as-code and deployment automation.

### IaC Security Scanning

**❌ BAD - No security validation:**
```bash
# Deploy without security checks
terraform apply -auto-approve
ansible-playbook site.yml
```

**✅ GOOD - Security validation pipeline:**
```bash
# Stage 1: Static analysis
terraform plan -out=tfplan
tfplan to json format
checkov -f tfplan.json  # Scan for security issues
tfsec .                  # Terraform security scan

# Stage 2: Lint checks
yamllint playbooks/
ansible-lint playbooks/

# Stage 3: Manual review
terraform plan  # Human review

# Stage 4: Deploy
terraform apply tfplan
```

### Host Hardening Playbook

```yaml
# roles/hardening/tasks/main.yml
---
- name: Disable unnecessary services
  service:
    name: "{{ item }}"
    state: stopped
    enabled: no
  loop:
    - telnet
    - rsh
    - rlogin
    - ftp

- name: Configure SSH security
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
    state: present
  loop:
    - regexp: "^#?PermitRootLogin"
      line: "PermitRootLogin no"
    - regexp: "^#?PasswordAuthentication"
      line: "PasswordAuthentication no"
    - regexp: "^#?Protocol"
      line: "Protocol 2"
    - regexp: "^#?X11Forwarding"
      line: "X11Forwarding no"
    - regexp: "^#?ClientAliveInterval"
      line: "ClientAliveInterval 300"
  notify: restart sshd

- name: Configure firewall
  block:
    - name: Enable UFW
      ufw:
        state: enabled
        policy: deny
        direction: incoming
    
    - name: Allow SSH
      ufw:
        rule: allow
        port: "22"
        proto: tcp
    
    - name: Allow HTTPS
      ufw:
        rule: allow
        port: "443"
        proto: tcp

- name: Enable SELinux (CentOS/RHEL)
  selinux:
    policy: targeted
    state: enforcing

- name: Configure system hardening
  sysctl:
    name: "{{ item.name }}"
    value: "{{ item.value }}"
    state: present
  loop:
    - name: net.ipv4.conf.all.send_redirects
      value: "0"
    - name: net.ipv4.conf.default.send_redirects
      value: "0"
    - name: net.ipv4.icmp_echo_ignore_broadcasts
      value: "1"
    - name: net.ipv4.tcp_syncookies
      value: "1"
```

---

## Container Security

Secure container images and runtime environments.

### Image Security

**❌ BAD - Vulnerable container:**
```dockerfile
# Dockerfile - INSECURE
FROM ubuntu:latest

# Running as root!
RUN apt-get update && \
    apt-get install -y curl wget git

# Unnecessary tools included
COPY . /app
WORKDIR /app

CMD ["python", "app.py"]
```

**✅ GOOD - Hardened container:**
```dockerfile
# Dockerfile - SECURE
FROM ubuntu:22.04 as base

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 \
      python3-pip && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# Multi-stage build - minimal final image
FROM base as production

WORKDIR /app
COPY --chown=appuser:appuser . /app

# Switch to non-root user
USER appuser:appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s \
    CMD python3 -c "import requests; requests.get('http://localhost:8000/health')"

ENTRYPOINT ["python3", "app.py"]
```

### Container Scanning in CI/CD

```yaml
# .gitlab-ci.yml
build_container:
  stage: build
  script:
    - docker build -t myapp:latest .
    - docker tag myapp:latest $REGISTRY/myapp:$CI_COMMIT_SHA

scan_container:
  stage: test
  script:
    # Scan for vulnerabilities
    - trivy image $REGISTRY/myapp:$CI_COMMIT_SHA
    
    # Check for security policies
    - conftest test -p /policies/container.rego myapp:latest
  allow_failure: false

push_container:
  stage: deploy
  script:
    - docker push $REGISTRY/myapp:$CI_COMMIT_SHA
  only:
    - main
```

### Kubernetes Pod Security

```yaml
# Pod security policy
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  
  requiredDropCapabilities:
    - ALL
  
  allowedCapabilities:
    - NET_BIND_SERVICE
  
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  
  hostNetwork: false
  hostIPC: false
  hostPID: false
  
  runAsUser:
    rule: 'MustRunAsNonRoot'
  
  seLinux:
    rule: 'MustRunAs'
    seLinuxOptions:
      level: "s0:c123,c456"
  
  readOnlyRootFilesystem: true
```

---

## Supply Chain Security

Secure the entire software supply chain from dependencies to deployment.

### Dependency Management

**❌ BAD - Uncontrolled dependencies:**
```yaml
# requirements.txt - No versions, no hashes
requests
django
numpy
pandas
flask
```

**✅ GOOD - Pinned and scanned dependencies:**
```yaml
# requirements.txt - Locked versions with hashes
requests==2.28.1 \
    --hash=sha256:7fff40c9d7d3a67332199a393f3c4b46b7879d15386056e48a27ef330b6abc0c
    
django==4.1.3 \
    --hash=sha256:084c4f2e0b26861b757158476ed1339aca5cb75957e23e27b2dabadb6c3e47be

numpy==1.23.5 \
    --hash=sha256:f72d0007c11e89c5f7a2a0d1d0b0d4e8e8b6b8e8f8e8f8e8e8e8e8e8e8e8
```

### Artifact Store Configuration

```yaml
# Enforce internal artifact stores (NO direct internet)
- name: Configure NPM artifact store
  copy:
    dest: ~/.npmrc
    content: |
      registry=https://nexus.company.com/repository/npm-all/
      @mycompany:registry=https://nexus.company.com/repository/npm-internal/
      always-auth=true
      _auth={{ nexus_auth_token | b64encode }}

- name: Configure pip artifact store
  copy:
    dest: ~/.pip/pip.conf
    content: |
      [global]
      index-url = https://nexus.company.com/repository/pypi-all/simple/
      extra-index-url = https://pypi.org/simple/

- name: Verify packages from internal store
  command: |
    npm view {{ package }} | grep -i "nexus.company.com"
  failed_when: false
```

### SBOM (Software Bill of Materials)

```yaml
# Generate SBOM for vulnerability tracking
- name: Generate SBOM for Python application
  command: cyclonedx-bom -o /tmp/bom.json
  environment:
    PYTHONPATH: /opt/app

- name: Upload SBOM for vulnerability scanning
  uri:
    url: "https://dependencytrack.company.com/api/v1/bom"
    method: POST
    body_format: json
    headers:
      X-API-Key: "{{ dependencytrack_api_key }}"
    body:
      bom: "{{ lookup('file', '/tmp/bom.json') }}"

- name: Check for known vulnerabilities
  command: |
    trivy sbom /tmp/bom.json --severity HIGH,CRITICAL
```

---

## Code Security

Implement security best practices in code development.

### SAST (Static Application Security Testing)

```yaml
# GitLab CI with code security scanning
code_quality:
  stage: test
  script:
    # SAST scanning
    - sonarqube-scanner \
        -Dsonar.projectKey=myapp \
        -Dsonar.sources=src/ \
        -Dsonar.host.url=$SONARQUBE_HOST \
        -Dsonar.login=$SONARQUBE_TOKEN
    
    # Secret scanning
    - truffleHog filesystem . --json > secrets-scan.json
    - |
      if grep -q "verified_secret" secrets-scan.json; then
        echo "Secrets detected in code!"
        exit 1
      fi
    
    # Dependency check
    - dependency-check --scan . --format JSON --out results.json
  artifacts:
    reports:
      sast: gl-sast-report.json
      dependency_scanning: gl-dependency-scanning-report.json
```

### Secure Coding Practices

**❌ BAD - SQL injection vulnerability:**
```python
# app.py - INSECURE
from flask import Flask, request
import sqlite3

app = Flask(__name__)

@app.route('/user/<user_id>')
def get_user(user_id):
    conn = sqlite3.connect('users.db')
    cursor = conn.cursor()
    
    # SQL INJECTION VULNERABILITY!
    query = f"SELECT * FROM users WHERE id = {user_id}"
    cursor.execute(query)
    
    return cursor.fetchone()
```

**✅ GOOD - Parameterized queries:**
```python
# app.py - SECURE
from flask import Flask, request
import sqlite3

app = Flask(__name__)

@app.route('/user/<user_id>')
def get_user(user_id):
    conn = sqlite3.connect('users.db')
    cursor = conn.cursor()
    
    # Parameterized query - prevents SQL injection
    query = "SELECT * FROM users WHERE id = ?"
    cursor.execute(query, (user_id,))
    
    return cursor.fetchone()
```

---

## Network Security

Implement network-level security controls.

### Network Segmentation

```yaml
# Kubernetes Network Policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-network-policy
spec:
  podSelector:
    matchLabels:
      app: webapp
  
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
  
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: database
      ports:
        - protocol: TCP
          port: 5432
    
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 53  # DNS
        - protocol: UDP
          port: 53
```

### VPC Security Configuration

```terraform
# terraform/network.tf
resource "aws_security_group" "application" {
  name        = "app-sg"
  description = "Application security group"
  vpc_id      = aws_vpc.main.id

  # Ingress: Only allow HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # From internet
    description = "HTTPS from internet"
  }

  # Ingress: SSH only from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "SSH from bastion only"
  }

  # Egress: Deny all by default
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
    description = "Default deny all"
  }

  # Egress: Allow HTTPS for updates
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to internet"
  }

  # Egress: Allow DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS queries"
  }
}
```

---

## Compliance and Audit

Implement compliance requirements and maintain audit trails.

### Compliance Requirements

**Common Frameworks:**
- **PCI-DSS**: Payment Card Industry Data Security Standard
- **HIPAA**: Healthcare data protection
- **SOC 2**: Service Organization Control
- **ISO 27001**: Information security management
- **GDPR**: General Data Protection Regulation
- **CIS Benchmarks**: Center for Internet Security

### Compliance Automation

```yaml
# roles/compliance_check/tasks/main.yml
---
- name: CIS Benchmark compliance check
  block:
    - name: Install CIS benchmark tool
      package:
        name: cis-cat
        state: present
    
    - name: Run CIS benchmark
      command: cis-cat --xml /tmp/cis-report.xml
      register: cis_result
    
    - name: Check critical findings
      xml:
        path: /tmp/cis-report.xml
        xpath: /Report/Benchmark/TestResult[@result='FAIL' and @severity='CRITICAL']
        count: yes
      register: critical_findings
    
    - name: Fail if critical findings
      fail:
        msg: "Critical CIS benchmark violations found: {{ critical_findings.count }}"
      when: critical_findings.count > 0

- name: Configure audit logging
  lineinfile:
    path: /etc/audit/rules.d/audit.rules
    line: "{{ item }}"
    state: present
  loop:
    - "-w /etc/shadow -p wa -k shadow-changes"
    - "-w /etc/sudoers -p wa -k sudoers-changes"
    - "-a always,exit -F arch=b64 -S adopen,adclose -F auid>=1000 -F auid!=-1 -k admin-actions"
  notify: restart auditd
```

### Audit Log Configuration

```yaml
# Kubernetes audit policy
apiVersion: audit.k8s.io/v1
kind: Policy

# Log all requests at the Metadata level
rules:
  # Log pod exec at RequestResponse level
  - level: RequestResponse
    verbs: ["create"]
    resources: ["pods/exec", "pods/attach"]
  
  # Log secret access
  - level: Metadata
    resources: ["secrets"]
  
  # Log authentication failures
  - level: Metadata
    userGroups: ["system:unauthenticated"]
  
  # Log changes to RBAC
  - level: RequestResponse
    resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]
  
  # Catch-all
  - level: Metadata
```

---

## Incident Response

Prepare and execute security incident response.

### Incident Response Plan

```yaml
# Incident Response Automation
- name: Incident Response Playbook
  hosts: all
  vars:
    incident_severity: "{{ severity | default('medium') }}"
  
  tasks:
    - name: Collect forensic data
      block:
        - name: Capture system state
          command: "{{ item }}"
          register: forensic_data
          loop:
            - "ps auxww"
            - "netstat -tupan"
            - "ss -tupan"
            - "iptables -L -n"
            - "lsof -i"
            - "journalctl --no-pager"
        
        - name: Save forensic data
          copy:
            content: "{{ forensic_data | to_nice_yaml }}"
            dest: "/tmp/forensics-{{ ansible_date_time.iso8601_basic_short }}.yml"
        
        - name: Archive logs
          archive:
            path: "/var/log"
            dest: "/tmp/logs-{{ ansible_date_time.iso8601_basic_short }}.tar.gz"
            mode: "0600"

    - name: Isolate compromised host
      block:
        - name: Disable network interfaces
          command: "ip link set dev {{ item }} down"
          loop: "{{ ansible_interfaces | difference(['lo']) }}"
          when: incident_severity == "critical"
        
        - name: Kill suspicious processes
          command: "pkill -f '{{ suspicious_process }}'"
          when: suspicious_process is defined
        
        - name: Revoke SSH access
          lineinfile:
            path: /etc/ssh/sshd_config
            line: "PermitRootLogin no"
            state: present
          notify: restart sshd

    - name: Notify security team
      uri:
        url: "{{ incident_webhook }}"
        method: POST
        body_format: json
        body:
          severity: "{{ incident_severity }}"
          host: "{{ inventory_hostname }}"
          timestamp: "{{ ansible_date_time.iso8601 }}"
          forensics: "{{ forensic_data }}"
      when: incident_severity in ['high', 'critical']
```

### Break-Glass Access

```yaml
# Emergency access procedure (Break-Glass)
- name: Emergency access setup
  block:
    - name: Create break-glass admin user
      user:
        name: breakglass
        password: "{{ breakglass_password | password_hash('sha512') }}"
        groups: ['wheel']
        shell: /bin/bash
      register: bg_user
      no_log: true
    
    - name: Store break-glass credentials in secure location
      command: |
        echo "{{ breakglass_password }}" | \
        gpg --always-trust --encrypt-to {{ gpg_key_id }} \
        --output /secure/breakglass-{{ inventory_hostname }}.gpg
      no_log: true
    
    - name: Alert security team
      mail:
        host: smtp.company.com
        port: 587
        to: security-team@company.com
        subject: "Break-Glass Access Created"
        body: "Emergency access account created on {{ inventory_hostname }}"
```

---

## Security Automation

Automate security best practices and continuous monitoring.

### Security Scanning Pipeline

```yaml
# CI/CD security scanning stages
stages:
  - secrets_scan
  - dependency_scan
  - sast
  - container_scan
  - infrastructure_scan
  - compliance_check

secrets_scan:
  stage: secrets_scan
  script:
    - truffleHog git https://github.com/myorg/myrepo --json
  allow_failure: false

dependency_scan:
  stage: dependency_scan
  script:
    - dependency-check --scan . --format HTML --out results.html
  artifacts:
    paths:
      - results.html
  allow_failure: true

sast_scan:
  stage: sast
  script:
    - sonarqube-scanner -Dsonar.projectKey=myapp
  allow_failure: true

container_scan:
  stage: container_scan
  script:
    - trivy image myregistry/myapp:latest
  allow_failure: true

infrastructure_scan:
  stage: infrastructure_scan
  script:
    - checkov -f terraform/
    - tfsec .
  allow_failure: true

compliance_check:
  stage: compliance_check
  script:
    - conftest test -p policies/ .
  allow_failure: false
```

### Continuous Security Monitoring

```yaml
# Falco runtime security monitoring
- name: Install Falco for runtime security
  block:
    - name: Add Falco repository
      apt_repository:
        repo: 'deb https://download.falco.org/packages/deb stable main'
        state: present
    
    - name: Install Falco
      package:
        name: falco
        state: present
    
    - name: Configure Falco rules
      copy:
        dest: /etc/falco/falco_rules.local.yaml
        content: |
          - rule: Unauthorized Process Execution
            desc: Detect unauthorized process execution
            condition: >
              spawned_process and 
              user != root and 
              proc_name in (nc, ncat, telnet, ssh)
            output: >
              Unauthorized process execution
              (user=%user.name command=%proc.cmdline)
            priority: WARNING
          
          - rule: Suspicious File Access
            desc: Detect access to sensitive files
            condition: >
              open and 
              fd.name in (/etc/shadow, /etc/passwd, /root/.ssh)
            output: >
              Suspicious file access
              (user=%user.name file=%fd.name)
            priority: WARNING
    
    - name: Start Falco service
      service:
        name: falco
        state: started
        enabled: yes
```

---

## Best Practices Checklist

### Before Deployment
- [ ] Secrets scanned and validated
- [ ] Dependencies checked for vulnerabilities
- [ ] SAST scan completed with no critical issues
- [ ] Container image scanned
- [ ] Infrastructure code scanned
- [ ] Compliance checks passed
- [ ] Security review completed

### During Deployment
- [ ] Audit logging enabled
- [ ] Network policies applied
- [ ] Host hardening completed
- [ ] Security groups configured
- [ ] RBAC policies enforced
- [ ] Monitoring and alerting active

### Post-Deployment
- [ ] Runtime security monitoring enabled
- [ ] Vulnerability scanning scheduled
- [ ] Compliance monitoring active
- [ ] Audit logs collected
- [ ] Incident response procedures tested
- [ ] Break-glass access verified

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [DevSecOps Best Practices](https://www.devsecops.org/)
- [Cloud Security Best Practices](https://cloudsecurity.org/)
- [Container Security](https://containersecurity.org/)

---

**Author**: Michael Vogeler  
**Last Updated**: December 2025  
**Maintained By**: Security & DevOps Team
