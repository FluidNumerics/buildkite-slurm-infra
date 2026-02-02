# Buildkite Agent Ansible Deployment

Ansible playbooks and roles for deploying Buildkite agents on Slurm clusters.

## Quick Start

1. **Configure your inventory:**
   ```bash
   cp inventories/example.ini inventories/production.ini
   # Edit with your cluster details
   vi inventories/production.ini
   ```

2. **Set variables:**
   ```bash
   vi group_vars/all.yml
   # Set your Buildkite agent token and cluster settings
   ```

3. **Deploy:**
   ```bash
   # Deploy everything
   ansible-playbook -i inventories/production.ini playbooks/site.yml

   # Or deploy step-by-step:
   ansible-playbook -i inventories/production.ini playbooks/provision-user.yml
   ansible-playbook -i inventories/production.ini playbooks/install-agent.yml
   ansible-playbook -i inventories/production.ini playbooks/configure-slurm.yml
   ```

## What Gets Deployed

- **All nodes**: buildkite-agent user with consistent UID/GID
- **Login nodes**: Buildkite agent service, hooks, and configuration
- **Controller nodes**: Slurm accounting entries for buildkite-agent user
- **Compute nodes**: buildkite-agent user for job execution

## Directory Structure

```
.
├── inventories/
│   └── example.ini           # Example inventory file
├── group_vars/
│   └── all.yml              # Global variables
├── roles/
│   ├── buildkite-agent-user/      # Create user on all nodes
│   ├── buildkite-agent-install/   # Install agent on login nodes
│   └── buildkite-slurm-setup/     # Configure Slurm accounting
└── playbooks/
    ├── site.yml             # Main playbook (runs all)
    ├── provision-user.yml   # Just user provisioning
    ├── install-agent.yml    # Just agent installation
    └── configure-slurm.yml  # Just Slurm configuration
```

## Requirements

- Ansible 2.9+
- SSH access to all nodes
- sudo privileges on all nodes
- Slurm cluster already configured

## Variables

Edit `group_vars/all.yml`:

```yaml
buildkite_agent_token: "your-agent-token-here"
buildkite_cluster_name: "galapagos"
buildkite_agent_uid: 998
buildkite_agent_gid: 996
slurm_account: "default"
```

## Testing

Test connectivity first:
```bash
ansible -i inventories/production.ini all -m ping
```

Test in check mode (dry-run):
```bash
ansible-playbook -i inventories/production.ini playbooks/site.yml --check
```

## Customization

### Different OS

The roles detect OS automatically (Ubuntu/Debian vs RHEL/Rocky) but you can override:

```yaml
# In group_vars/all.yml
buildkite_agent_os_family: "redhat"  # or "debian"
```

### Custom Hooks

Place custom hooks in `roles/buildkite-agent-install/files/hooks/` before running.

### Multiple Agents per Node

```yaml
# In group_vars/all.yml
buildkite_agent_spawn: 2
```

## Troubleshooting

### UID/GID Already in Use

If the UIDs conflict:
```bash
# Check existing users
ansible -i inventories/production.ini all -a "getent passwd 998"

# Change in group_vars/all.yml
buildkite_agent_uid: 1998
buildkite_agent_gid: 1996
```

### Agent Not Starting

```bash
# Check status on login nodes
ansible -i inventories/production.ini login_nodes -a "systemctl status buildkite-agent"

# Check logs
ansible -i inventories/production.ini login_nodes -a "journalctl -u buildkite-agent -n 50"
```

### Slurm Database Issues

```bash
# Verify user in Slurm
ansible -i inventories/production.ini slurm_controllers -a "sacctmgr show user buildkite-agent -s"
```
