# Ansible Examples

Production-ready Ansible configurations for infrastructure automation.

## Quick Start

### 1. Setup Inventory

```bash
# Copy inventory to your environment
cp inventory.yml /etc/ansible/hosts

# Test inventory
ansible all -i inventory.yml -m ping
```

### 2. Run Common Playbook

```bash
# Apply common configuration to all hosts
ansible-playbook -i inventory.yml common.yml --check

# Apply without check
ansible-playbook -i inventory.yml common.yml
```

### 3. Deploy to Specific Environment

```bash
# Deploy to development
ansible-playbook -i inventory.yml site.yml -e "target=development"

# Deploy to production with approval
ansible-playbook -i inventory.yml site.yml -e "target=production" --ask-vault-pass
```

## File Structure

- `inventory.yml` - Multi-environment inventory with groups
- `site.yml` - Master playbook
- `common.yml` - Common configuration for all hosts
- `webservers.yml` - Web server configuration
- `databases.yml` - Database configuration
- `monitoring.yml` - Monitoring setup

## Key Features

✅ Multi-environment support (dev/staging/prod)
✅ Role-based grouping
✅ SSH hardening
✅ Firewall configuration
✅ Health checks
✅ Error handling and retries
✅ Idempotent operations

## Security Considerations

- SSH keys only (no passwords)
- Non-root user deployments
- Firewall rules configured
- Regular updates enabled
- Log rotation setup

## Troubleshooting

### SSH Connection Issues
```bash
# Test SSH connectivity
ansible all -i inventory.yml -m ping

# Debug SSH connection
ansible-playbook -i inventory.yml site.yml -vvv
```

### Check Mode (Dry Run)
```bash
# Preview changes without applying
ansible-playbook -i inventory.yml site.yml --check --diff
```

### Gather Facts
```bash
# Collect system information
ansible all -i inventory.yml -m setup
```

## References

- [Ansible Best Practices](../01-ansible-best-practices.md)
- [Official Ansible Documentation](https://docs.ansible.com/)
