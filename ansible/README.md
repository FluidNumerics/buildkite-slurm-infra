# Buildkite Agent Ansible Deployment

Ansible playbooks and roles for deploying Buildkite agents on Slurm clusters.

## Quick Start

1. **Configure your inventory:**
   ```bash
   cp inventory/example.ini inventory/production.ini
   # Edit with your cluster details
   vi inventory/production.ini
   ```

2. **Set variables:**
   ```bash
   cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml
   vi inventory/group_vars/all.yml
   # Set your Buildkite agent token and cluster settings
   ```

3. **Deploy:**
   ```bash
   # Deploy everything
   ansible-playbook -i inventory/production.ini playbooks/site.yml

   # Or deploy step-by-step:
   ansible-playbook -i inventory/production.ini playbooks/provision-user.yml
   ansible-playbook -i inventory/production.ini playbooks/install-agent.yml
   ansible-playbook -i inventory/production.ini playbooks/configure-slurm.yml
   ```

## What Gets Deployed

- **All nodes**: buildkite-agent user with consistent UID/GID
- **Login nodes**: Buildkite agent service, hooks, and configuration
- **Controller nodes**: Slurm accounting entries for buildkite-agent user
- **Compute nodes**: buildkite-agent user for job execution

## Directory Structure

```
.
├── inventory/
│   ├── example.ini              # Example inventory file
│   └── group_vars/
│       ├── all.yml              # Your configuration (gitignored)
│       └── all.yml.example      # Example configuration
├── roles/
│   ├── buildkite-agent-user/    # Create user on all nodes
│   ├── buildkite-agent-install/ # Install agent on login nodes
│   └── buildkite-slurm-setup/   # Configure Slurm accounting
└── playbooks/
    ├── site.yml                 # Main playbook (runs all)
    ├── provision-user.yml       # User provisioning
    ├── install-agent.yml        # Agent installation
    └── configure-slurm.yml      # Slurm configuration
```

## Requirements

- Ansible 2.9+
- SSH access to all nodes
- sudo privileges on all nodes
- Slurm cluster already configured

## Variables

Edit `inventory/group_vars/all.yml` (copy from `all.yml.example` first):

```yaml
# Required
buildkite_agent_token: "your-agent-token-here"
buildkite_cluster_name: "your-cluster-name"

# User configuration
buildkite_agent_uid: 998
buildkite_agent_gid: 996
buildkite_agent_home: /home/buildkite-agent

# Slurm configuration
slurm_bin: "/usr/local/bin"
slurm_account: "default"
slurm_create_ci_account: true
slurm_ci_account_name: "ci-account"

# Agent configuration
buildkite_agent_spawn: 1
buildkite_build_path: "{{ buildkite_agent_home }}/builds"
buildkite_hooks_path: "/etc/buildkite-agent/hooks"
```

See `inventory/group_vars/all.yml.example` for the full list of available variables.

## Testing

Test connectivity first:
```bash
ansible -i inventory/production.ini all -m ping
```

Test in check mode (dry-run):
```bash
ansible-playbook -i inventory/production.ini playbooks/site.yml --check
```

## Customization

### Different OS

The roles detect OS automatically (Ubuntu/Debian vs RHEL/Rocky) but you can override:

```yaml
# In inventory/group_vars/all.yml
buildkite_agent_os_family: "redhat"  # or "debian"
```

### Custom Hooks

Hooks are deployed from Jinja2 templates in `roles/buildkite-agent-install/templates/hooks/`:
- `pre-command.j2` - Wraps commands with srun based on agent metadata (automatically skips `buildkite-agent` subcommands like `pipeline upload`)
- `environment.j2` - Sets up environment variables

Edit these templates to customize hook behavior for your cluster.

## Pipeline Configuration

Jobs **must** specify SLURM options via agent metadata. Running directly on the login node is not permitted, with the exception of `buildkite-agent` subcommands (e.g., `pipeline upload`, `artifact upload`) which are automatically detected and allowed to run on the agent node.

### Basic Example

```yaml
steps:
  - label: ":rocket: Build"
    command: "make build"
    agents:
      queue: "your-cluster-name"
      slurm_ntasks: "1"
      slurm_time: "00:30:00"
      slurm_partition: "batch"
```

### Available SLURM Options

Use `slurm_<option>` format in the agents block. Options map directly to srun arguments:

| Agent Metadata | srun Argument | Example |
|----------------|---------------|---------|
| `slurm_ntasks` | `--ntasks` | `"4"` |
| `slurm_cpus_per_task` | `--cpus-per-task` | `"8"` |
| `slurm_time` | `--time` | `"01:00:00"` |
| `slurm_partition` | `--partition` | `"batch"` |
| `slurm_gpus` | `--gpus` | `"1"` |
| `slurm_gpus_per_node` | `--gpus-per-node` | `"2"` |
| `slurm_mem` | `--mem` | `"16G"` |
| `slurm_nodes` | `--nodes` | `"2"` |
| `slurm_exclusive` | `--exclusive` | `"true"` |
| `slurm_container_image` | `--container-image` | `"ubuntu:22.04"` |

Any srun option can be specified using this pattern. See [srun documentation](https://slurm.schedmd.com/srun.html) for all available options.

### GPU Job Example

```yaml
steps:
  - label: ":gpu: GPU Training"
    command: "python train.py"
    agents:
      queue: "your-cluster-name"
      slurm_partition: "gpu"
      slurm_gpus: "1"
      slurm_time: "04:00:00"
      slurm_mem: "32G"
```

### Container Job Example

When using `slurm_container_image`, the hook automatically mounts the build checkout directory to `/workspace` and sets it as the working directory:

```yaml
steps:
  - label: ":docker: Container Build"
    command: "cmake --build ."
    agents:
      queue: "your-cluster-name"
      slurm_container_image: "nvcr.io/nvidia/cuda:12.0-devel-ubuntu22.04"
      slurm_ntasks: "1"
      slurm_time: "01:00:00"
```

Additional mounts can be specified with `slurm_container_mounts` and will be appended to the default workspace mount:

```yaml
steps:
  - label: ":docker: Container with Extra Mounts"
    command: "./run_analysis.sh"
    agents:
      queue: "your-cluster-name"
      slurm_container_image: "nvcr.io/nvidia/cuda:12.0-devel-ubuntu22.04"
      slurm_container_mounts: "/scratch:/scratch,/datasets:/data:ro"
      slurm_ntasks: "1"
      slurm_time: "02:00:00"
```

This results in mounts: `$BUILDKITE_BUILD_CHECKOUT_PATH:/workspace,/scratch:/scratch,/datasets:/data:ro`

### Multi-node MPI Example

```yaml
steps:
  - label: ":computer: MPI Job"
    command: "mpirun ./my_application"
    agents:
      queue: "your-cluster-name"
      slurm_nodes: "4"
      slurm_ntasks_per_node: "8"
      slurm_time: "02:00:00"
      slurm_partition: "compute"
```

### Multiple Agents per Node

```yaml
# In inventory/group_vars/all.yml
buildkite_agent_spawn: 2
```

## Troubleshooting

### UID/GID Already in Use

If the UIDs conflict:
```bash
# Check existing users
ansible -i inventory/production.ini all -a "getent passwd 998"

# Change in inventory/group_vars/all.yml
buildkite_agent_uid: 1998
buildkite_agent_gid: 1996
```

### Agent Not Starting

```bash
# Check status on login nodes
ansible -i inventory/production.ini login_nodes -a "systemctl status buildkite-agent"

# Check logs
ansible -i inventory/production.ini login_nodes -a "journalctl -u buildkite-agent -n 50"
```

### Slurm Database Issues

```bash
# Verify user in Slurm
ansible -i inventory/production.ini slurm_controllers -a "sacctmgr show user buildkite-agent -s"
```

