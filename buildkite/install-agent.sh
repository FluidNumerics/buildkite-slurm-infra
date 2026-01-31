#!/bin/bash
set -euo pipefail

echo "=== Buildkite Agent Installation ==="
echo

# Check for agent token
AGENT_TOKEN="${1:-}"
if [ -z "$AGENT_TOKEN" ]; then
  echo "ERROR: Agent token required"
  echo "Usage: $0 <agent-token>"
  echo
  echo "Get your agent token from:"
  echo "  Buildkite Dashboard > Organization Settings > Agents"
  exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "ERROR: Cannot detect OS"
  exit 1
fi

echo "Detected OS: $OS"
echo

# Install based on OS
case $OS in
  ubuntu|debian)
    echo "Installing for Ubuntu/Debian..."
    curl -fsSL https://keys.openpgp.org/vks/v1/by-fingerprint/32A37959C2FA5C3C99EFBC32A79206696452D198 | \
      gpg --dearmor | sudo tee /usr/share/keyrings/buildkite-agent-archive-keyring.gpg > /dev/null
    
    echo "deb [signed-by=/usr/share/keyrings/buildkite-agent-archive-keyring.gpg] https://apt.buildkite.com/buildkite-agent stable main" | \
      sudo tee /etc/apt/sources.list.d/buildkite-agent.list
    
    sudo apt-get update
    sudo apt-get install -y buildkite-agent
    ;;
    
  rhel|centos|rocky|almalinux)
    echo "Installing for RHEL/CentOS..."
    sudo sh -c 'echo -e "[buildkite-agent]\nname = Buildkite Pty Ltd\nbaseurl = https://yum.buildkite.com/buildkite-agent/stable/x86_64/\nenabled=1\ngpgcheck=0\npriority=1" > /etc/yum.repos.d/buildkite-agent.repo'
    sudo yum -y install buildkite-agent
    ;;
    
  *)
    echo "ERROR: Unsupported OS: $OS"
    echo "Please install manually: https://buildkite.com/docs/agent/v3/installation"
    exit 1
    ;;
esac

# Configure agent
echo
echo "Configuring agent..."
sudo sed -i "s/xxx/${AGENT_TOKEN}/g" /etc/buildkite-agent/buildkite-agent.cfg

# Detect cluster name from Slurm
echo
echo "Detecting Slurm cluster name..."
CLUSTER_NAME=""

# Try multiple methods to detect cluster name
if command -v sacctmgr &> /dev/null; then
  CLUSTER_NAME=$(sacctmgr show cluster -n -P format=Cluster 2>/dev/null | head -1)
fi

if [ -z "$CLUSTER_NAME" ] && command -v scontrol &> /dev/null; then
  CLUSTER_NAME=$(scontrol show config | grep -i "ClusterName" | awk '{print $3}')
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo "WARNING: Could not detect cluster name from Slurm"
  echo "Using default queue name: gpu"
  CLUSTER_NAME="gpu"
else
  echo "Detected cluster: $CLUSTER_NAME"
fi

# Set tags with detected cluster name
echo "tags=\"queue=${CLUSTER_NAME},slurm=true\"" | sudo tee -a /etc/buildkite-agent/buildkite-agent.cfg
echo 'tags-from-host=true' | sudo tee -a /etc/buildkite-agent/buildkite-agent.cfg

echo
echo "=== Installation Complete ==="
echo
echo "Agent configured with:"
echo "  Queue: $CLUSTER_NAME"
echo "  Tags: slurm=true"
echo
echo "Next steps:"
echo "  1. Edit buildkite/hooks/pre-command to match your cluster partitions"
echo "  2. Run: ./scripts/deploy-hooks.sh"
echo "  3. Verify: sudo systemctl status buildkite-agent"
echo "  4. In your pipelines, use: agents: { queue: \"${CLUSTER_NAME}\" }"
echo
