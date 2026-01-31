# Buildkite + Slurm CI Infrastructure

Infrastructure for running Buildkite CI/CD on Slurm clusters with multiple GPU architectures.

## Quick Start

1. **Install Buildkite agent on cluster login/submit node:**
   ```bash
   ./buildkite/install-agent.sh <your-buildkite-agent-token>
   ```
   The agent will automatically detect your Slurm cluster name and use it as the queue tag.

2. **Configure for your cluster:**
   Edit `buildkite/hooks/pre-command` to set your partition names and constraints

3. **Deploy hooks:**
   ```bash
   ./scripts/deploy-hooks.sh
   ```

4. **In your project repositories:**
   Copy `.buildkite/pipeline.yml` from `buildkite/examples/` and customize
   - Replace `queue: "your-cluster-name"` with your actual cluster name
   - Or use `queue: "*"` to run on any available Slurm cluster

## Cluster Detection

The installation script automatically detects your Slurm cluster name using:
1. `sacctmgr show cluster` (preferred)
2. `scontrol show config | grep ClusterName` (fallback)

The detected cluster name becomes the queue tag, allowing you to:
- Target specific clusters: `agents: { queue: "cluster-a" }`
- Run on any cluster: `agents: { queue: "*" }`
- Manage multiple clusters with the same infrastructure repo

## Architecture

- **Agent:** Runs on login/submit nodes, polls Buildkite for jobs
- **Hooks:** Intercept commands and submit to Slurm via sbatch
- **Pipeline:** Standard Buildkite YAML in your project repos

## Supported GPU Architectures

Customize partition names in `buildkite/hooks/pre-command`

## Documentation

- [Setup Guide](docs/setup.md)
- [Troubleshooting](docs/troubleshooting.md)

## Repository Structure

```
buildkite/
├── install-agent.sh       # Agent installation
├── hooks/
│   ├── pre-command        # Slurm submission logic
│   ├── environment        # Environment setup per GPU arch
│   └── pre-exit          # Cleanup
└── examples/
    └── pipeline.yml       # Example pipeline template

scripts/
└── deploy-hooks.sh        # Deploy/update hooks on agent

docs/
├── setup.md               # Detailed setup instructions
└── troubleshooting.md     # Common issues
```

## Updating Hooks

When you modify hooks:
```bash
./scripts/deploy-hooks.sh
```

## Multiple Agents

To run multiple agents for better throughput:
```bash
# Enable multiple instances
sudo systemctl enable buildkite-agent@1
sudo systemctl enable buildkite-agent@2
sudo systemctl start buildkite-agent@1
sudo systemctl start buildkite-agent@2
```
