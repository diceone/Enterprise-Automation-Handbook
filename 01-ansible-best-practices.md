# Ansible Best Practices

A comprehensive guide for DevOps Engineers on implementing Ansible automation effectively and reliably.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Inventory Management](#inventory-management)
3. [Playbook Design](#playbook-design)
4. [Variables and Secrets](#variables-and-secrets)
5. [Roles and Reusability](#roles-and-reusability)
6. [Error Handling and Idempotency](#error-handling-and-idempotency)
7. [Performance Optimization](#performance-optimization)
8. [Testing and Validation](#testing-and-validation)
9. [Documentation and Maintenance](#documentation-and-maintenance)
10. [Security Best Practices](#security-best-practices)

---

## Project Structure

### Recommended Directory Layout

```
ansible-project/
├── README.md                          # Project overview
├── requirements.txt                   # Python dependencies
├── ansible.cfg                        # Ansible configuration
├── inventory/
│   ├── production/
│   │   ├── hosts.yml                 # Production inventory
│   │   └── group_vars/               # Group-specific variables
│   │       ├── webservers.yml
│   │       ├── databases.yml
│   │       └── all.yml               # Variables for all groups
│   ├── staging/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   └── development/
│       ├── hosts.yml
│       └── group_vars/
├── playbooks/
│   ├── site.yml                       # Master playbook
│   ├── deploy.yml
│   ├── provision.yml
│   └── maintenance.yml
├── roles/
│   ├── common/
│   │   ├── tasks/
│   │   ├── handlers/
│   │   ├── templates/
│   │   ├── files/
│   │   └── defaults/
│   ├── webserver/
│   ├── database/
│   └── monitoring/
├── group_vars/
├── host_vars/
├── templates/
├── files/
├── library/                           # Custom modules
├── plugins/                           # Custom plugins
├── tests/
│   └── test_playbooks.yml
└── .gitignore
```

### Key Principles

- **Modularity**: Each role should have a single responsibility
- **Clarity**: Organize by function, not by environment initially
- **Reusability**: Share roles across projects via Ansible Galaxy or internal repositories
- **Scalability**: Support multiple environments without code duplication

---

## Inventory Management

### Inventory Structure Best Practices

#### 1. Use YAML Format for Clarity

```yaml
---
# inventory/production/hosts.yml

all:
  vars:
    ansible_user: deploy
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    
  children:
    webservers:
      hosts:
        web01.prod.local:
          ansible_host: 10.1.1.10
        web02.prod.local:
          ansible_host: 10.1.1.11
      vars:
        http_port: 80
        max_clients: 200
        
    databases:
      hosts:
        db01.prod.local:
          ansible_host: 10.1.2.10
      vars:
        mysql_port: 3306
        
    monitoring:
      hosts:
        mon01.prod.local:
          ansible_host: 10.1.3.10
```

#### 2. Organize Group Variables

```yaml
# inventory/production/group_vars/webservers.yml
---
webserver_packages:
  - nginx
  - curl
  - git

nginx_user: nginx
nginx_worker_processes: auto
nginx_max_clients: 2048
```

#### 3. Dynamic Inventory for Cloud Environments

Use plugins for AWS, Azure, GCP, or other cloud providers:

```yaml
# ansible.cfg
[inventory]
enable_plugins = aws_ec2, azure_rm, gcp_compute
```

```yaml
# inventory/aws_ec2.yml
plugin: aws_ec2
regions:
  - us-east-1
filters:
  tag:Environment: production
  tag:ManagedBy: ansible
compose:
  ansible_host: private_ip_address
```

### Dynamic Inventory Patterns

- Use cloud provider plugins for automatic scaling
- Cache results to avoid API throttling
- Use keyed_groups for dynamic group creation
- Keep static inventory as fallback

---

## Playbook Design

### Common Ansible Patterns

#### 1. Loop Patterns

**Iterate over list:**
```yaml
- name: Install multiple packages
  package:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - curl
    - git
```

**Iterate with index:**
```yaml
- name: Configure hosts with index
  lineinfile:
    path: /etc/hosts
    line: "{{ item.1 }} {{ item.0 }}"
  loop: "{{ groups['webservers'] | list | zip(ip_addresses) | list }}"
```

**Iterate over dictionary:**
```yaml
- name: Create users with properties
  user:
    name: "{{ item.key }}"
    uid: "{{ item.value.uid }}"
    groups: "{{ item.value.groups }}"
  loop: "{{ users | dict2items }}"
```

#### 2. Conditional Patterns

**Simple conditions:**
```yaml
- name: Configure service
  template:
    src: service.conf.j2
    dest: /etc/service.conf
  when: service_enabled | bool
```

**Complex conditions:**
```yaml
- name: Deploy on specific conditions
  block:
    - name: Perform deployment
      command: /opt/deploy.sh
      
  when:
    - ansible_os_family == "Debian"
    - inventory_hostname in groups['webservers']
    - service_version is defined
    - service_version is version('1.0', '>')
```

#### 3. Delegation and Local Tasks

**Delegate task to specific host:**
```yaml
- name: Configure load balancer
  hosts: webservers
  tasks:
    - name: Remove from load balancer
      command: "lbctl remove {{ inventory_hostname }}"
      delegate_to: "{{ groups['loadbalancers'][0] }}"
      
    - name: Deploy application
      command: /opt/deploy.sh
      
    - name: Add back to load balancer
      command: "lbctl add {{ inventory_hostname }}"
      delegate_to: "{{ groups['loadbalancers'][0] }}"
```

**Run task locally:**
```yaml
- name: Deploy from control node
  hosts: all
  tasks:
    - name: Generate certificate locally
      local_action:
        module: command
        cmd: "openssl req -new -keyout {{ cert_key }}"
      run_once: true
      
    - name: Copy certificate to remote
      copy:
        src: "{{ cert_key }}"
        dest: /etc/ssl/private/
```

#### 4. Rolling Deployment Pattern

**Deploy with minimal downtime:**
```yaml
---
- name: Rolling deployment
  hosts: webservers
  serial: 1  # Deploy one host at a time
  max_fail_percentage: 0  # Stop if any fails
  
  tasks:
    - name: Drain connections
      command: drain_service.sh
      delegate_to: "{{ groups['loadbalancers'][0] }}"
      
    - name: Stop application
      service:
        name: app
        state: stopped
        
    - name: Deploy new version
      copy:
        src: app-{{ version }}.tar.gz
        dest: /opt/app/
        
    - name: Extract and validate
      unarchive:
        src: /opt/app/app-{{ version }}.tar.gz
        dest: /opt/app/
        remote_src: yes
      notify: restart app
      
    - name: Wait for service to be ready
      wait_for:
        port: 8080
        delay: 10
        timeout: 60
        
    - name: Run health checks
      uri:
        url: http://localhost:8080/health
        method: GET
      register: health
      until: health.status == 200
      retries: 5
      delay: 5
      
    - name: Add back to load balancer
      command: add_service.sh
      delegate_to: "{{ groups['loadbalancers'][0] }}"
  
  handlers:
    - name: restart app
      service:
        name: app
        state: restarted
```

#### 5. Async and Background Tasks

**Long-running operations:**
```yaml
- name: Perform long-running tasks
  hosts: webservers
  tasks:
    - name: Start backup in background
      command: /opt/backup.sh
      async: 3600  # Maximum 1 hour
      poll: 0  # Don't wait
      register: backup_job
      
    - name: Do other work while backup runs
      debug:
        msg: "Backup started with job ID {{ backup_job.ansible_job_id }}"
        
    - name: Check backup status
      async_status:
        jid: "{{ backup_job.ansible_job_id }}"
      register: backup_result
      until: backup_result.finished
      retries: 60
      delay: 60
```

### Playbook Structure

#### Simple Playbook Example

```yaml
---
- name: Configure web servers
  hosts: webservers
  become: true
  gather_facts: true
  
  pre_tasks:
    - name: Update package cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"
  
  tasks:
    - name: Install required packages
      package:
        name: "{{ item }}"
        state: present
      loop: "{{ webserver_packages }}"
      
    - name: Configure nginx
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: '0644'
        backup: yes
      notify: restart nginx
  
  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted
        
  post_tasks:
    - name: Verify nginx is running
      command: systemctl is-active nginx
      changed_when: false
```

### Playbook Best Practices

| Practice | Reason |
|----------|--------|
| Use descriptive task names | Improves logging and debugging |
| Always use `gather_facts: true` | Required for os-specific logic |
| Leverage handlers for service restarts | Avoids unnecessary restarts |
| Use `changed_when` and `failed_when` | Precise control over task status |
| Include tags for selective execution | Enables targeted deployments |
| Use `check_mode` compatible tasks | Supports dry-run validation |

### Master Playbook Pattern

```yaml
---
# site.yml - Master playbook
- name: Configure all systems
  import_playbook: playbooks/common.yml
  
- name: Configure web tier
  import_playbook: playbooks/webservers.yml
  
- name: Configure database tier
  import_playbook: playbooks/databases.yml
  
- name: Deploy monitoring
  import_playbook: playbooks/monitoring.yml
```

---

## Variables and Secrets

### Variable Hierarchy (Highest to Lowest Priority)

1. Command-line extra variables (`-e`)
2. Task variables
3. Block variables
4. Play variables
5. Role and include variables
6. Set facts
7. Host facts
8. Host variables (host_vars/)
9. Group variables (group_vars/)
10. Inventory variables
11. Role defaults

### Variable Naming Conventions

```yaml
# Use descriptive, namespaced variables
app_name: myapp
app_version: "1.2.3"
app_config_dir: /etc/myapp
app_data_dir: /var/lib/myapp

# For roles, prefix with role name
webserver_port: 80
webserver_user: www-data
database_host: db.example.com
```

### Managing Secrets

#### Option 1: Ansible Vault

```bash
# Create encrypted variable file
ansible-vault create inventory/production/group_vars/databases/vault.yml

# Edit encrypted file
ansible-vault edit inventory/production/group_vars/databases/vault.yml

# Run playbook with vault password
ansible-playbook -i inventory/production site.yml --ask-vault-pass

# Use vault password file (CI/CD)
ansible-playbook -i inventory/production site.yml --vault-password-file ~/.vault_pass
```

Vault file structure:

```yaml
---
# inventory/production/group_vars/databases/vault.yml (encrypted)
vault_db_password: "secure_password_123"
vault_api_key: "api_key_xyz"
```

Access in playbooks:

```yaml
---
- name: Configure database
  mysql_user:
    name: app_user
    password: "{{ vault_db_password }}"  # References vault variable
    state: present
```

#### Option 2: External Secret Management (Recommended for Production)

```yaml
---
- name: Retrieve secrets from HashiCorp Vault
  hosts: all
  tasks:
    - name: Get database credentials
      community.general.hashi_vault:
        url: https://vault.example.com
        path: secret/data/prod/database
        auth_method: jwt
        role_id: "{{ vault_role_id }}"
        jwt: "{{ vault_jwt_token }}"
      register: db_secrets
      
    - name: Use retrieved secrets
      mysql_user:
        name: app_user
        password: "{{ db_secrets.secret.data.password }}"
```

### Environment-Specific Variables

```yaml
# group_vars/all/main.yml
environment: "{{ ansible_env_type | default('development') }}"
environment_vars: "{{ lookup('file', 'env_vars_' ~ environment ~ '.yml') | from_yaml }}"

# Then reference as: environment_vars.api_timeout
```

---

## Roles and Reusability

### Role Structure

```
roles/webserver/
├── tasks/
│   ├── main.yml
│   ├── install.yml
│   └── configure.yml
├── handlers/
│   └── main.yml
├── templates/
│   ├── nginx.conf.j2
│   └── ssl.conf.j2
├── files/
│   └── dhparam.pem
├── vars/
│   └── main.yml                    # Role-specific variables (not overridable)
├── defaults/
│   └── main.yml                    # Default variables (overridable)
├── meta/
│   └── main.yml                    # Role metadata and dependencies
└── tests/
    ├── test.yml
    └── inventory.ini
```

### Role Best Practices

#### 1. Use Defaults for Overridable Values

```yaml
# roles/webserver/defaults/main.yml
---
webserver_packages:
  - nginx
  - curl

webserver_port: 80
webserver_user: www-data
webserver_document_root: /var/www/html
```

#### 2. Document Role Dependencies

```yaml
# roles/webserver/meta/main.yml
---
galaxy_info:
  author: DevOps Team
  description: Installs and configures Nginx web server
  company: Your Company
  license: MIT
  min_ansible_version: 2.20
  platforms:
    - name: Ubuntu
      versions:
        - 18.04
        - 20.04
        - 22.04
    - name: CentOS
      versions:
        - 7
        - 8

dependencies:
  - role: common
    vars:
      common_packages: "{{ webserver_base_packages }}"
```

#### 3. Organize Complex Role Tasks

```yaml
# roles/webserver/tasks/main.yml
---
- name: Include OS-specific tasks
  include_tasks: "{{ ansible_os_family }}.yml"

- name: Include installation tasks
  include_tasks: install.yml

- name: Include configuration tasks
  include_tasks: configure.yml
```

#### 4. Reuse Roles Across Projects

```yaml
# requirements.yml
---
collections:
  - community.general
  - ansible.posix

roles:
  - name: geerlingguy.java
    src: https://github.com/geerlingguy/ansible-role-java.git
    version: master
    
  - name: internal.webserver
    src: https://git.internal.company/ansible/roles/webserver.git
    version: v1.2.0
```

Install dependencies:

```bash
ansible-galaxy install -r requirements.yml
```

---

## Error Handling and Idempotency

### Idempotency Principles

**Idempotency** is a fundamental requirement: running a playbook multiple times must produce the same result without side effects or errors.

**Why Idempotency Matters:**
- ✅ Safe to re-run playbooks without risk
- ✅ Enables automated remediation and drift correction
- ✅ Supports reliable automation in production
- ✅ Allows confident recovery from failures
- ✅ Essential for GitOps and declarative infrastructure

#### Idempotent vs Non-Idempotent Examples

**❌ NON-IDEMPOTENT - Do NOT use:**
```yaml
# Problem: Running twice creates issues
- name: Append line to file (NOT idempotent)
  shell: echo "config_option=true" >> /etc/app.conf
  # Running twice adds the line twice!
  
# Problem: Always reports changed
- name: Run script (NOT idempotent)
  command: /opt/setup.sh
  # Ansible can't determine if change occurred

# Problem: Modifies state unpredictably
- name: Update config with sed (NOT idempotent)
  shell: sed -i 's/old_value/new_value/g' /etc/config.yml
  # Multiple runs may cause unintended changes
```

**✅ IDEMPOTENT - Do use:**
```yaml
# Solution: Use lineinfile module (idempotent)
- name: Ensure configuration line exists (IDEMPOTENT)
  lineinfile:
    path: /etc/app.conf
    line: "config_option=true"
    state: present
  # Running multiple times: no changes after first run
  
# Solution: Register and check (idempotent)
- name: Check if setup is required
  stat:
    path: /opt/.setup_complete
  register: setup_status
  
- name: Run setup only if needed (IDEMPOTENT)
  command: /opt/setup.sh
  when: not setup_status.stat.exists
  
- name: Mark as complete
  file:
    path: /opt/.setup_complete
    state: touch

# Solution: Use built-in modules (idempotent)
- name: Manage configuration file (IDEMPOTENT)
  template:
    src: config.yml.j2
    dest: /etc/config.yml
    owner: root
    group: root
    mode: '0644'
    backup: yes
  # Idempotent: only changes if template content differs
  notify: restart service
```

#### Idempotency Testing Strategy

```bash
# Test 1: Run playbook twice and verify idempotency
ansible-playbook -i inventory site.yml
FIRST_RUN=$?

ansible-playbook -i inventory site.yml
SECOND_RUN=$?

# Verify: Second run should have no changes (changed=0, failed=0)
if [ $SECOND_RUN -eq 0 ]; then
  echo "✓ Playbook is idempotent"
else
  echo "✗ Playbook is NOT idempotent - second run failed"
  exit 1
fi
```

### Advanced Error Handling Patterns

#### 1. Retry and Until Patterns

**Retry transient failures:**
```yaml
- name: Deploy with automatic retry
  command: /opt/deploy.sh
  register: deploy_result
  retries: 3
  delay: 10
  until: deploy_result.rc == 0
```

**Wait for condition:**
```yaml
- name: Wait for service to become healthy
  uri:
    url: "http://{{ inventory_hostname }}:8080/health"
    method: GET
  register: result
  until: result.status == 200 and result.json.status == 'healthy'
  retries: 30
  delay: 10
  timeout: 300
```

#### 2. Register and Set Facts

**Capture output for later use:**
```yaml
- name: Get current version
  command: cat /opt/app/VERSION
  register: current_version
  changed_when: false
  
- name: Deploy only if version differs (IDEMPOTENT)
  block:
    - name: Deploy new version
      command: /opt/deploy.sh {{ new_version }}
      
  when: current_version.stdout != new_version
```

**Set dynamic facts:**
```yaml
- name: Calculate deployment parameters
  set_fact:
    deployment_window: "{{ deployment_start_time | to_datetime('%Y-%m-%d %H:%M') }}"
    batch_size: "{{ groups['webservers'] | length // 4 }}"
    should_restart: "{{ config_changed or service_failed }}"
    
- name: Use calculated facts
  debug:
    msg: "Deploying {{ batch_size }} hosts per batch"
```

#### 3. Block-Rescue-Always Pattern

**Structured error handling with rollback:**
```yaml
- name: Deployment with fallback
  hosts: webservers
  tasks:
    - name: Try new deployment
      block:
        - name: Stop current service
          service:
            name: app
            state: stopped
            
        - name: Backup current version
          copy:
            src: /opt/app/current
            dest: /opt/app/backup
            remote_src: yes
            
        - name: Deploy new version
          unarchive:
            src: app-{{ version }}.tar.gz
            dest: /opt/app/
            
        - name: Run smoke tests
          command: /opt/app/bin/test
          register: test_result
          failed_when: test_result.rc != 0
          
      rescue:
        - name: Restore from backup
          copy:
            src: /opt/app/backup
            dest: /opt/app/current
            remote_src: yes
            
        - name: Restart previous version
          service:
            name: app
            state: started
            
        - name: Alert operations team
          mail:
            host: smtp.example.com
            subject: "Deployment failed on {{ inventory_hostname }}"
            body: "Error: {{ test_result.stderr }}"
          delegate_to: localhost
          
        - name: Stop deployment
          fail:
            msg: "Deployment failed - rolled back to previous version"
            
      always:
        - name: Clean up temporary files
          file:
            path: /tmp/app_*
            state: absent
            
        - name: Log deployment result
          syslog:
            msg: "Deployment attempt: {{ 'SUCCESS' if test_result is succeeded else 'FAILED' }}"
```

### Idempotent Task Design

**Non-idempotent (Avoid):**
```yaml
- name: Add line to file (NOT idempotent)
  shell: echo "new_line" >> /etc/config.conf
```

**Idempotent (Recommended):**
```yaml
- name: Add line to file (idempotent)
  lineinfile:
    path: /etc/config.conf
    line: "new_line"
    state: present
```

### Error Handling Patterns

#### 1. Handle Specific Failures

```yaml
---
- name: Deploy application
  hosts: webservers
  tasks:
    - name: Stop application
      service:
        name: myapp
        state: stopped
      ignore_errors: yes
      
    - name: Deploy new version
      copy:
        src: myapp-latest.tar.gz
        dest: /opt/myapp/
        
    - name: Extract and validate
      block:
        - name: Extract archive
          unarchive:
            src: /opt/myapp/myapp-latest.tar.gz
            dest: /opt/myapp/
            remote_src: yes
            
        - name: Run validation tests
          command: /opt/myapp/bin/validate
          register: validation_result
          
        - name: Validate passed
          debug:
            msg: "Deployment validation successful"
            
      rescue:
        - name: Rollback on failure
          command: /opt/myapp/bin/rollback
          
        - name: Start previous version
          service:
            name: myapp
            state: started
            
        - name: Fail playbook
          fail:
            msg: "Deployment validation failed: {{ validation_result.stderr }}"
```

#### 2. Use Handlers for Conditional Restarts

```yaml
---
- name: Configure service
  hosts: all
  tasks:
    - name: Update configuration
      template:
        src: service.conf.j2
        dest: /etc/service.conf
        backup: yes
      register: config_updated
      notify: restart service
      
    - name: Flush handlers to ensure restart
      meta: flush_handlers
      
    - name: Verify service health
      command: systemctl is-active service
      changed_when: false
      
  handlers:
    - name: restart service
      service:
        name: service
        state: restarted
      when: config_updated.changed
```

#### 3. Validate Before Proceeding

```yaml
---
- name: Safe deployment workflow
  hosts: webservers
  tasks:
    - name: Check current deployment status
      stat:
        path: /opt/current_deployment.txt
      register: current_deployment
      
    - name: Read current version
      command: cat /opt/current_deployment.txt
      register: current_version
      when: current_deployment.stat.exists
      changed_when: false
      
    - name: Deploy only if version differs
      block:
        - name: Perform deployment
          command: /opt/deploy.sh
          
        - name: Record new version
          copy:
            content: "{{ new_version }}"
            dest: /opt/current_deployment.txt
            
      when: current_version.stdout | default('') != new_version
```

---

## Performance Optimization

### Reducing Execution Time

#### 1. Enable Pipelining

```ini
# ansible.cfg
[defaults]
pipelining = True
```

#### 2. Use Fact Caching

```ini
# ansible.cfg
[defaults]
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400
```

#### 3. Parallelize Execution

```bash
# Run tasks on 10 hosts in parallel (default is 5)
ansible-playbook -i inventory site.yml -f 10
```

#### 4. Minimize Data Transfer

```yaml
---
- name: Efficient data handling
  hosts: all
  tasks:
    - name: Avoid unnecessary facts
      gather_facts: no
      when: role_name != 'common'
      
    - name: Use local_action for non-remote tasks
      local_action:
        module: command
        cmd: git clone https://repo.git
      run_once: true
```

#### 5. Batch Operations

```yaml
---
- name: Install multiple packages efficiently
  hosts: all
  tasks:
    - name: Install packages in batch
      package:
        name: "{{ webserver_packages }}"
        state: present
      # More efficient than looping
```

### Profiling and Analysis

```bash
# Enable callback plugins for timing information
ANSIBLE_STDOUT_CALLBACK=profile_tasks ansible-playbook -i inventory site.yml

# Generate detailed timing report
ansible-playbook -i inventory site.yml -vvv --profile
```

---

## Testing and Validation

### Playbook Testing Strategies

#### 1. Dry-Run (Check Mode)

```bash
# Simulate playbook execution without making changes
ansible-playbook -i inventory site.yml --check

# Generate check report
ansible-playbook -i inventory site.yml --check --diff
```

#### 2. Syntax Validation

```bash
# Check playbook syntax
ansible-playbook -i inventory site.yml --syntax-check

# Lint with ansible-lint
ansible-lint site.yml
```

#### 3. Integration Testing

```yaml
# tests/integration/test_webserver.yml
---
- name: Test webserver role
  hosts: localhost
  gather_facts: false
  roles:
    - role: webserver
      vars:
        webserver_port: 8080
        
  post_tasks:
    - name: Verify nginx is installed
      command: which nginx
      changed_when: false
      
    - name: Verify nginx can start
      service:
        name: nginx
        state: started
      
    - name: Test HTTP response
      uri:
        url: http://localhost:8080
        method: GET
      register: response
      
    - name: Validate response
      assert:
        that:
          - response.status == 200
        fail_msg: "HTTP response code is {{ response.status }}, expected 200"
```

#### 4. Molecule for Role Testing

**Molecule** is the industry-standard tool for testing Ansible roles comprehensively.

**Setup Molecule for a Role:**

```bash
# Create new role with molecule integration
ansible-galaxy role init --init-path roles my_webserver

# Add molecule to existing role
cd roles/webserver
molecule init scenario -d docker
```

**Molecule Directory Structure:**

```
roles/webserver/
├── molecule/
│   ├── default/              # Default test scenario
│   │   ├── molecule.yml      # Molecule configuration
│   │   ├── converge.yml      # Playbook to apply role
│   │   ├── verify.yml        # Post-deploy verification
│   │   └── tests/            # Test files
│   │       └── test_default.py
│   ├── ubuntu_20.04/         # Alternative scenario
│   │   └── molecule.yml
│   └── centos_8/             # Another scenario
│       └── molecule.yml
├── tasks/
├── defaults/
└── meta/
```

**molecule.yml - Test Configuration:**

```yaml
---
dependency:
  name: galaxy
  requirements-file: requirements.yml

driver:
  name: docker
  options:
    ansible_connection_options:
      ansible_connection: docker

platforms:
  - name: ubuntu-20.04
    image: geerlingguy/docker-ubuntu2004-ansible
    pre_build_image: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    privileged: true
    command: /lib/systemd/systemd-cgroups-agent
    
  - name: centos-8
    image: geerlingguy/docker-centos8-ansible
    pre_build_image: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    privileged: true
    command: /lib/systemd/systemd-cgroups-agent

provisioner:
  name: ansible
  playbooks:
    converge: converge.yml
    verify: verify.yml
  inventory:
    group_vars:
      all:
        nginx_port: 80
        nginx_user: www-data

verifier:
  name: ansible

lint: |
  set -e
  yamllint .
  ansible-lint
```

**converge.yml - Apply Role:**

```yaml
---
- name: Converge - Apply webserver role
  hosts: all
  gather_facts: yes
  roles:
    - role: webserver
```

**verify.yml - Post-Deploy Tests (IDEMPOTENT CHECK):**

```yaml
---
- name: Verify - Test webserver role
  hosts: all
  gather_facts: no
  tasks:
    - name: Check nginx is installed
      command: which nginx
      changed_when: false
      failed_when: false
      register: nginx_check
      
    - name: Assert nginx installed
      assert:
        that:
          - nginx_check.rc == 0
        fail_msg: "nginx is not installed"
        
    - name: Verify nginx service is running
      systemd:
        name: nginx
        state: started
      register: nginx_service
      
    - name: Check nginx config syntax
      command: nginx -t
      changed_when: false
      register: nginx_config_test
      
    - name: Assert config is valid
      assert:
        that:
          - nginx_config_test.rc == 0
        fail_msg: "nginx config validation failed"
        
    - name: Test HTTP endpoint
      uri:
        url: "http://localhost:{{ nginx_port }}"
        method: GET
        status_code: 200
      register: http_response
      
    - name: Verify idempotency - Run role again
      include_role:
        name: webserver
      
    - name: Check no changes on second run
      assert:
        that:
          - not webserver_changed
        fail_msg: "Role is NOT idempotent - made changes on second run"
```

**Running Molecule Tests:**

```bash
# Run full test lifecycle (create → converge → verify → destroy)
molecule test

# Run specific scenario
molecule test -s ubuntu_20.04

# Test only specific host
molecule test -s default ubuntu-20.04

# Converge (apply role without destroying)
molecule converge

# Verify (run verify.yml)
molecule verify

# Clean up
molecule destroy

# Interactive testing
molecule create      # Start containers
molecule converge    # Apply role
molecule verify      # Verify
# Make changes and test manually...
molecule destroy     # Clean up

# Lint code
molecule lint
```

**Integration with CI/CD:**

```yaml
# .gitlab-ci.yml
test:molecule:
  stage: test
  image: python:3.9
  before_script:
    - pip install molecule[docker] ansible
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - cd roles/webserver
    - molecule test -s default
  only:
    - merge_requests
    - main
```

**Idempotency Testing with Molecule:**

```yaml
# verify.yml - includes idempotency check
---
- name: Verify Role and Test Idempotency
  hosts: all
  gather_facts: yes
  
  pre_tasks:
    - name: Run role first time
      include_role:
        name: webserver
      register: first_run
      
  tasks:
    - name: Run role second time (idempotency test)
      include_role:
        name: webserver
      register: second_run
      
    - name: Verify idempotency
      assert:
        that:
          - second_run.changed == false
        fail_msg: |
          Role is NOT idempotent!
          First run changed: {{ first_run.changed }}
          Second run changed: {{ second_run.changed }}
          
    - name: Verify services are running
      service:
        name: nginx
        state: started
        enabled: yes
      register: service_status
      
    - name: Assert service running
      assert:
        that:
          - not service_status.changed
        fail_msg: "Service was restarted - indicates missing idempotency"
```

---

## Documentation and Maintenance

### Self-Documenting Playbooks

```yaml
---
# Documentation in play level
- name: Deploy web application
  hosts: webservers
  
  # Document the purpose
  # This playbook handles the deployment pipeline:
  # 1. Downloads new application code
  # 2. Validates application integrity
  # 3. Performs rolling deployment (IDEMPOTENT)
  # 4. Executes health checks
  # 5. Rolls back on failure
  
  tasks:
    - name: Download application from artifact repository
      get_url:
        url: "{{ artifact_url }}/app-{{ version }}.tar.gz"
        dest: "/tmp/app-{{ version }}.tar.gz"
        checksum: "sha256:{{ artifact_checksum }}"
      tags:
        - deploy
        - download
        
    - name: Extract application
      unarchive:
        src: "/tmp/app-{{ version }}.tar.gz"
        dest: /opt/app/
        remote_src: yes
      tags:
        - deploy
        - extract
```

### README for Playbooks

```markdown
# Web Server Deployment Playbook

## Purpose
Deploys and configures web application servers with Nginx reverse proxy.

## Prerequisites
- Ansible 2.9+
- Python 3.6+
- SSH access to target hosts
- Vault password for sensitive data

## Variables

### Required
- `app_version`: Version of application to deploy (e.g., 1.2.3)
- `artifact_url`: URL to application artifact repository

### Optional
- `webserver_port`: Web server port (default: 80)
- `max_clients`: Maximum concurrent connections (default: 2048)

## Execution

### Dry Run
```bash
ansible-playbook -i inventory/production playbooks/deploy.yml --check --diff
```

### Full Deployment
```bash
ansible-playbook -i inventory/production playbooks/deploy.yml -e app_version=1.2.3
```

### Specific Tags
```bash
ansible-playbook -i inventory/production playbooks/deploy.yml --tags deploy --skip-tags validate
```

## Rollback
```bash
ansible-playbook -i inventory/production playbooks/rollback.yml -e previous_version=1.2.2
```
```

### Version Control Best Practices

```bash
# .gitignore for Ansible projects
*.retry
*.vault
.venv/
__pycache__/
*.pyc
.cache/
.molecule/
*.log
```

---

## Security Best Practices

### 1. SSH Key Management

```yaml
# Use SSH keys instead of passwords
- name: Configure SSH access
  authorized_key:
    user: deploy
    state: present
    key: "{{ lookup('file', 'public_keys/deploy.pub') }}"
```

```ini
# ansible.cfg
[defaults]
private_key_file = ~/.ssh/id_rsa
host_key_checking = True
```

### 2. Privilege Escalation

```yaml
---
- name: Tasks requiring elevated privileges
  hosts: webservers
  become: true              # Become root
  become_user: root
  become_method: sudo       # Use sudo (not su)
  
  tasks:
    - name: Install system package
      package:
        name: nginx
        state: present
```

### 3. Auditing and Logging

```yaml
---
- name: Enable audit logging
  hosts: all
  tasks:
    - name: Configure syslog forwarding
      template:
        src: rsyslog.conf.j2
        dest: /etc/rsyslog.d/30-forward.conf
        owner: root
        group: root
        mode: '0644'
      notify: restart rsyslog
      
    - name: Record deployment events
      syslog:
        msg: "Deployment of {{ app_version }} completed by Ansible"
```

### 4. Minimize Attack Surface

```yaml
---
- name: Security hardening
  hosts: all
  tasks:
    - name: Remove unnecessary packages
      package:
        name: "{{ item }}"
        state: absent
      loop:
        - telnet
        - rsh-server
        - nis
        
    - name: Configure firewall rules
      firewalld:
        port: "{{ item.port }}/{{ item.protocol }}"
        permanent: yes
        state: enabled
      loop:
        - { port: 22, protocol: tcp }
        - { port: 80, protocol: tcp }
        - { port: 443, protocol: tcp }
```

### 5. Regular Updates and Patching

```yaml
---
- name: Security updates
  hosts: all
  tasks:
    - name: Update all packages
      package:
        name: '*'
        state: latest
      
    - name: Reboot if required
      reboot:
        msg: "Rebooting after security updates"
      when: 
        - ansible_os_family == "Debian"
        - kernel_update_required | default(false)
```

---

## Troubleshooting Tips

| Issue | Solution | Pattern | Example |
|-------|----------|---------|---------|
| Task hangs indefinitely | Use `async` and `poll` parameters | Async pattern | `async: 3600, poll: 0` |
| Variable not found | Check variable precedence and scope | Group/Host variables | Use `group_vars/`, `host_vars/` |
| Permission denied | Verify `become` settings and sudo permissions | Become at play level | `become: true, become_user: root` |
| SSH timeout | Increase `ansible_timeout` in ansible.cfg | Connection settings | `ansible_timeout: 60` |
| Module not found | Install required collection or module | Check requirements.yml | `ansible-galaxy install -r requirements.yml` |
| Idempotency issues | Use built-in modules instead of shell commands | Idempotent task design | Use `lineinfile` instead of `shell echo` |
| Deployment fails midway | Use block-rescue for rollback | Block-rescue pattern | Wrap in `block:` with `rescue:` |
| Slow execution | Enable pipelining, reduce facts gathering | Performance optimization | `pipelining = True` in ansible.cfg |
| Service not ready after restart | Use wait_for with until/retries | Retry and until patterns | `until: health.status == 200` |
| Rolling deployment stuck | Check serial and max_fail_percentage settings | Rolling deployment pattern | `serial: 1, max_fail_percentage: 0` |
| Configuration drift detected | Validate before proceeding with block-rescue | Register and conditional | Use `stat:` to check existing state |
| Secrets exposed in logs | Always use `no_log: true` for sensitive tasks | Security best practice | `no_log: true` on vault tasks |
| Template rendering errors | Check Jinja2 syntax and variable availability | Template and Jinja2 filters | Test templates with `ansible-playbook --syntax-check` |

## Pattern Quick Reference

| Pattern | Primary Use | Key Considerations | When to Use |
|---------|-------------|-------------------|------------|
| **Loop** | Iterate collections | Use `loop` not deprecated `with_*` | Installing packages, creating users |
| **Conditional** | Execute based on state | Early exit more efficient than late | Environment-specific tasks |
| **Delegation** | Run on specific host | Must have SSH connectivity | Load balancer updates, control node tasks |
| **Block-Rescue** | Error handling | Always block executes regardless | Deployments with rollback needs |
| **Async** | Long-running tasks | Use `poll: 0` then check with `async_status` | Backups, downloads, system updates |
| **Rolling** | Gradual deployment | `serial` with `max_fail_percentage` | Zero-downtime application updates |
| **Retry/Until** | Transient failure handling | Combine with appropriate delays | Service startup, API calls, connectivity checks |
| **Register** | Capture output | Use `changed_when: false` for reads | Conditional deployment, log capturing |
| **Template** | Dynamic config generation | Use Jinja2 for calculations | Configuration file generation |
| **Delegation + Run Once** | Centralized actions | Most efficient for control node tasks | Certificate generation, artifact downloads |

---

## References and Resources

- [Official Ansible Documentation](https://docs.ansible.com/)
- [Ansible Galaxy - Curated Collections](https://galaxy.ansible.com/)
- [Ansible Best Practices by RedHat](https://www.redhat.com/en/blog/ansible-best-practices)
- [ansible-lint for Code Quality](https://github.com/ansible/ansible-lint)

---

## References and Resources

- [Official Ansible Documentation](https://docs.ansible.com/)
- [Ansible Galaxy - Curated Collections](https://galaxy.ansible.com/)
- [Ansible Best Practices by RedHat](https://www.redhat.com/en/blog/ansible-best-practices)
- [ansible-lint for Code Quality](https://github.com/ansible/ansible-lint)

---

**Version**: 1.1  
**Author**: Michael Vogeler  
**Last Updated**: December 1, 2025  
**Maintained By**: DevOps Team

## Common Playbook Templates

### Service Configuration Template

Use this template when configuring new services:

```yaml
---
- name: Configure {{ service_name }}
  hosts: "{{ target_hosts }}"
  become: true
  
  vars:
    service_port: "{{ service_port | default(8080) }}"
    service_user: "{{ service_user | default(service_name) }}"
    
  pre_tasks:
    - name: Validate variables
      assert:
        that:
          - service_name is defined
          - target_hosts is defined
        fail_msg: "Required variables not defined"
        
  tasks:
    - name: Create service user
      user:
        name: "{{ service_user }}"
        shell: /usr/sbin/nologin
        home: "/var/lib/{{ service_name }}"
        createhome: yes
        state: present
        
    - name: Install service packages
      package:
        name: "{{ service_packages }}"
        state: present
      register: pkg_install
      
    - name: Configure service
      template:
        src: "{{ service_name }}.conf.j2"
        dest: "/etc/{{ service_name }}/config"
        owner: "{{ service_user }}"
        group: "{{ service_user }}"
        mode: '0644'
        backup: yes
      notify: "restart {{ service_name }}"
      
    - name: Enable and start service
      service:
        name: "{{ service_name }}"
        state: started
        enabled: yes
        
  handlers:
    - name: "restart {{ service_name }}"
      service:
        name: "{{ service_name }}"
        state: restarted
```

### Health Check and Validation Template

```yaml
---
- name: Validate deployment
  hosts: "{{ target_hosts }}"
  tasks:
    - name: Check service is running
      service_facts:
      register: services
      
    - name: Verify service is active
      assert:
        that:
          - services.ansible_facts.services['{{ service_name }}.service'].state == 'running'
        fail_msg: "{{ service_name }} is not running"
        
    - name: Check application health endpoint
      uri:
        url: "http://localhost:{{ service_port }}/health"
        method: GET
      register: health
      until: health.status == 200
      retries: 5
      delay: 5
      
    - name: Verify application response
      assert:
        that:
          - health.json.status == 'healthy'
          - health.json.version == expected_version
        fail_msg: "Health check failed"
```

### Maintenance Window Template

```yaml
---
- name: Maintenance with minimal downtime
  hosts: "{{ target_hosts }}"
  serial: "{{ (groups[target_hosts] | length / 2) | int }}"
  max_fail_percentage: 0
  
  pre_tasks:
    - name: Notify monitoring system
      command: "notify-monitoring.sh {{ inventory_hostname }} maintenance-start"
      delegate_to: "{{ groups['monitoring'][0] }}"
      
  tasks:
    - name: Drain connections
      block:
        - name: Stop accepting new connections
          command: "service-control drain"
          
        - name: Wait for existing connections to close
          wait_for:
            path: /var/run/service.lock
            state: absent
            timeout: 300
            
  post_tasks:
    - name: Restore normal operation
      command: "service-control restore"
      
    - name: Notify monitoring system
      command: "notify-monitoring.sh {{ inventory_hostname }} maintenance-complete"
      delegate_to: "{{ groups['monitoring'][0] }}"
```
