#!/bin/bash
set -euo pipefail

echo "=== Deploying Buildkite Hooks ==="
echo

HOOKS_DIR="/etc/buildkite-agent/hooks"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_HOOKS="$SCRIPT_DIR/../buildkite/hooks"

# Check if hooks exist
if [ ! -d "$REPO_HOOKS" ]; then
  echo "ERROR: Hooks directory not found: $REPO_HOOKS"
  exit 1
fi

# Create hooks directory
sudo mkdir -p "$HOOKS_DIR"

# Deploy each hook
DEPLOYED=0
for hook in "$REPO_HOOKS"/*; do
  if [ -f "$hook" ]; then
    HOOK_NAME=$(basename "$hook")
    echo "Deploying: $HOOK_NAME"
    sudo cp "$hook" "$HOOKS_DIR/"
    sudo chmod +x "$HOOKS_DIR/$HOOK_NAME"
    DEPLOYED=$((DEPLOYED + 1))
  fi
done

echo
echo "Deployed $DEPLOYED hook(s)"
echo

# Restart agent
echo "Restarting Buildkite agent..."
if sudo systemctl restart buildkite-agent; then
  echo "Agent restarted successfully"
else
  echo "WARNING: Failed to restart agent"
  echo "Try manually: sudo systemctl restart buildkite-agent"
fi

echo
echo "=== Deployment Complete ==="
echo
echo "Verify hooks:"
echo "  ls -la $HOOKS_DIR"
echo
echo "Check agent status:"
echo "  sudo systemctl status buildkite-agent"
