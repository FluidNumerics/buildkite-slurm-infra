# Buildkite + Slurm CI Infrastructure

Ansible-based infrastructure for deploying Buildkite CI/CD agents on Slurm clusters.

## Quick Start

See [ansible/README.md](ansible/README.md) for deployment instructions.

## Architecture

- **Agent:** Runs on login/submit nodes, polls Buildkite for jobs
- **Hooks:** Intercept commands and submit to Slurm via sbatch
- **Pipeline:** Standard Buildkite YAML in your project repos

## Repository Structure

```
ansible/
├── inventory/
│   ├── example.ini              # Example inventory file
│   └── group_vars/
│       ├── all.yml              # Your configuration (gitignored)
│       └── all.yml.example      # Example configuration
├── playbooks/
│   ├── site.yml                 # Main playbook (runs all)
│   ├── provision-user.yml       # User provisioning
│   ├── install-agent.yml        # Agent installation
│   └── configure-slurm.yml      # Slurm configuration
└── roles/
    ├── buildkite-agent-user/    # Create user on all nodes
    ├── buildkite-agent-install/ # Install agent on login nodes
    └── buildkite-slurm-setup/   # Configure Slurm accounting
```
