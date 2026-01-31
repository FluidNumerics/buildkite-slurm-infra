# Troubleshooting

## Agent Not Showing Up in Buildkite UI

**Check agent is running:**
```bash
sudo systemctl status buildkite-agent
```

**Check agent logs:**
```bash
sudo journalctl -u buildkite-agent -f
```

**Check agent tags:**
```bash
grep "^tags=" /etc/buildkite-agent/buildkite-agent.cfg
```

**Common issues:**
- Wrong agent token
- Network connectivity issues
- Agent config syntax error

**Verify config:**
```bash
sudo cat /etc/buildkite-agent/buildkite-agent.cfg
```

## Cluster Name Not Detected

If the installation script couldn't detect your cluster name:

**Manually check cluster name:**
```bash
sacctmgr show cluster -n -P format=Cluster
# or
scontrol show config | grep ClusterName
```

**Manually set queue tag:**
```bash
sudo vi /etc/buildkite-agent/buildkite-agent.cfg
# Update the tags line:
tags="queue=your-cluster-name,slurm=true"

# Restart agent
sudo systemctl restart buildkite-agent
```

**If Slurm commands fail:**
- Ensure Slurm is properly installed and configured
- Check that the buildkite-agent user can run Slurm commands
- Verify Slurm database is accessible

## Jobs Stuck in Queue

**Check Slurm partitions:**
```bash
sinfo
squeue
```

**Check agent can submit jobs:**
```bash
sbatch --wrap="echo test"
```

**Verify partition names in hooks:**
```bash
cat /etc/buildkite-agent/hooks/pre-command
```

## Container Not Found

**Check container path:**
```bash
ls -la /path/to/base-v100.sqsh
```

**Verify enroot/pyxis:**
```bash
srun --container-image=/path/to/base-v100.sqsh echo "test"
```

**Common issues:**
- Container path not accessible from compute nodes
- Wrong filesystem (containers must be on shared FS)
- Container image corrupted

## Jobs Fail with "Permission Denied"

**Check buildkite-agent user can submit to Slurm:**
```bash
sudo -u buildkite-agent sbatch --wrap="echo test"
```

**Check file permissions on checkout directory:**
```bash
ls -la /var/lib/buildkite-agent/builds/
```

## Hooks Not Running

**Check hook permissions:**
```bash
ls -la /etc/buildkite-agent/hooks/
# All hooks should be executable (chmod +x)
```

**Check hook syntax:**
```bash
bash -n /etc/buildkite-agent/hooks/pre-command
```

**Enable hook debugging:**
```bash
# Add to top of hook
set -x  # Print all commands
```

## Logs Not Appearing in Buildkite

**Check log file path:**
```bash
# In pre-command hook, verify LOG_FILE path is correct
# Must be accessible to both submit node and compute nodes
```

**Check tail command:**
```bash
# Ensure tail is not failing silently
tail -f /path/to/log/file
```

## Build Checkout Fails

**Check git access from login node:**
```bash
sudo -u buildkite-agent git clone <your-repo-url>
```

**For private repos, set up SSH keys:**
```bash
sudo -u buildkite-agent ssh-keygen
# Add public key to GitHub/GitLab
```

## High Queue Times

**Options:**
1. Run multiple agent instances
2. Increase Slurm time limits in hook
3. Use QoS or reservations for CI jobs
4. Set up dedicated CI partition

## Getting Help

**Useful diagnostic commands:**
```bash
# Agent status
sudo systemctl status buildkite-agent
sudo journalctl -u buildkite-agent -n 100

# Slurm status
squeue -u buildkite-agent
sacct -u buildkite-agent -S now-1day

# Hook debugging
sudo bash -x /etc/buildkite-agent/hooks/pre-command
```

**Buildkite support:**
- Documentation: https://buildkite.com/docs
- Community forum: https://forum.buildkite.com
- Support: support@buildkite.com
