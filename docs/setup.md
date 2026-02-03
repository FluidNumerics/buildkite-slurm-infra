# Buildkite + Slurm Setup Guide

## Prerequisites

- Slurm cluster with GPU partitions
- Login/submit node where you can run long-running services
- Buildkite account (free tier available)
- Enroot + Pyxis for container support (optional but recommended)

## Step 1: Create Buildkite Organization

1. Sign up at https://buildkite.com
2. Create an organization
3. Go to Organization Settings → Agents
4. Create an agent token (keep this secure)

## Step 2: Install Agent on Cluster

On your cluster login/submit node:

```bash
git clone <this-repo>
cd buildkite-slurm-infra

# Install agent
./buildkite/install-agent.sh <your-agent-token>
```

## Step 3: Customize for Your Cluster

Edit `buildkite/hooks/pre-command` and update partition names:

```bash
vi buildkite/hooks/pre-command

# Update these sections:
  v100)
    PARTITION="your-v100-partition-name"
    CONSTRAINT="your-v100-constraint"
    ;;
  mi210)
    PARTITION="your-mi210-partition-name"
    CONSTRAINT="your-mi210-constraint"
    ;;
```

Check your partition names:
```bash
sinfo -o "%P %N %G"
```

## Step 4: Deploy Hooks

```bash
./scripts/deploy-hooks.sh
```

Verify deployment:
```bash
ls -la /etc/buildkite-agent/hooks/
```

## Step 5: Verify Agent is Running

```bash
sudo systemctl status buildkite-agent
sudo journalctl -u buildkite-agent -f
```

Check the agent tags to verify cluster name detection:
```bash
grep "^tags=" /etc/buildkite-agent/buildkite-agent.cfg
```

In the Buildkite web UI, you should see your agent appear under:
Organization Settings → Agents

The agent will show tags like:
- `queue=your-cluster-name` (auto-detected from Slurm)
- `slurm=true`
- Plus any host-derived tags

## Step 6: Set Up Your First Project

1. In Buildkite, create a new pipeline
2. Point it to your GitHub/GitLab repo
3. In your repo, create `.buildkite/pipeline.yml`:

```bash
mkdir -p .buildkite
cp <path-to-this-repo>/buildkite/examples/pipeline.yml .buildkite/pipeline.yml
```

4. Customize the pipeline for your project:
   - Update container image paths
   - Adjust build commands
   - Set appropriate GPU architectures

## Step 7: Trigger Your First Build

Push a commit or manually trigger a build in Buildkite UI.

Monitor:
- Buildkite UI for build progress
- `squeue` on cluster for Slurm jobs
- Agent logs: `sudo journalctl -u buildkite-agent -f`

## Container Setup

Your container images should be available on a shared filesystem:

```bash
# Example: Store containers in shared location
/shared/containers/
├── base-v100.sqsh
├── base-mi210.sqsh
└── base-mi300a.sqsh
```

Update paths in your pipeline.yml to match your setup.

## Using Multiple Clusters

If you're deploying agents on multiple clusters, each will automatically tag itself with its cluster name. In your pipelines, you can:

**Target a specific cluster:**
```yaml
agents:
  queue: "cluster-a"
  slurm: "true"
```

**Run on any available cluster:**
```yaml
agents:
  queue: "*"
  slurm: "true"
```

**Run different steps on different clusters:**
```yaml
steps:
  - label: "Quick test"
    agents:
      queue: "dev-cluster"
  
  - label: "Long validation"
    agents:
      queue: "production-cluster"
```

You can check your cluster name with:
```bash
sacctmgr show cluster -n -P format=Cluster
# or
scontrol show config | grep ClusterName
```

## Multiple Agents (Optional)

For better throughput, run multiple agent instances:

```bash
sudo systemctl enable buildkite-agent@1
sudo systemctl enable buildkite-agent@2
sudo systemctl start buildkite-agent@1
sudo systemctl start buildkite-agent@2
```


## Giving your agent an ssh key
The `buildkite-agent`, needs to have an ssh key associated with its posix account and that ssh key needs to be aligned with an account on github that has read permissions to your repository. An ed25519 ssh key for the `buildkit-agent` is created with the provided ansible scripts. You can get the public key by running

```
sudo cat /var/lib/buildkite-agent/.ssh/id_ed25519.pub
```
## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues.

