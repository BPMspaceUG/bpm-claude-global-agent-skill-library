# Audit Checklist — Full Command Reference

## Bootstrap

### Determine Host Identity
```bash
HOSTNAME=$(hostname)
REPO="bpm-${HOSTNAME}"
ORG="BPMspaceUG"
```

### rootmessages user
```bash
id rootmessages 2>/dev/null
sudo -l -U rootmessages 2>/dev/null | grep "NOPASSWD: ALL"
ls -la /home/rootmessages/
```
- MUST exist with `sudo NOPASSWD: ALL`
- If missing → create user and configure sudo (requires human confirmation)

### Host-Repo
```bash
# Check GitHub via MCP: search for bpm-${HOSTNAME} in org BPMspaceUG
# mcp__github__search_repositories query:"${REPO} org:${ORG}"
```
- If repo does NOT exist → create via `mcp__github__create_repository`:
  - name: `bpm-{hostname}`, org: BPMspaceUG, private: true, autoInit: true
  - description: "Linux audit & hardening tracking for {hostname}"
- Then retroactively create Issue #1: "Host-Repo bootstrap for {hostname}"
  - Include: date, creator, purpose, hostname, OS version, IP address
  - This is the ONE exception where action precedes issue

### Local Clone
```bash
ls -d /home/rootmessages/bpm-${HOSTNAME}/.git 2>/dev/null
# If not cloned: git clone to /home/rootmessages/bpm-${HOSTNAME}/
# If exists: cd /home/rootmessages/bpm-${HOSTNAME} && git pull
```

### Lifecycle Milestones
Create via GitHub MCP if they don't exist:
```
new, planned, plan-approved, test-designed, test-design-approved,
implemented, tested-success, tested-failed, test-approved, DONE
```

---

## A. Runtime Environment

### A1. Symlink shadowing
```bash
for bin in node npm npx python3 php bun deno bunx pnpm yarn; do
  target=$(readlink -f /usr/local/bin/$bin 2>/dev/null)
  [ -n "$target" ] && echo "SHADOW: /usr/local/bin/$bin -> $target"
done
```

### A2. Multiple versions in PATH
```bash
which -a node npm python3 php 2>/dev/null
```

### A3. User-local runtime dirs
```bash
for home in /home/* /root; do
  for dir in .bun .nvm .pyenv .deno .npm .yarn; do
    [ -d "$home/$dir" ] && echo "FOUND: $home/$dir ($(du -sh "$home/$dir" 2>/dev/null | cut -f1))"
  done
done
```

### A4. PATH manipulation
```bash
grep -rn 'PATH.*bun\|PATH.*nvm\|PATH.*deno\|PATH.*pyenv' /etc/profile.d/ /home/*/.bashrc /home/*/.profile 2>/dev/null
```

### A5. System runtime versions
```bash
/usr/bin/node --version 2>/dev/null
/usr/bin/npm --version 2>/dev/null
/usr/bin/python3 --version 2>/dev/null
/usr/bin/php --version 2>/dev/null | head -1
```

---

## B. Security Baseline

### B1. SSH configuration
```bash
sudo grep -E "^(PasswordAuthentication|PermitRootLogin|PubkeyAuthentication|ChallengeResponseAuthentication)" /etc/ssh/sshd_config
```

### B2. Firewall
```bash
sudo ufw status verbose
sudo ss -tulpn
```

### B3. Security updates
```bash
sudo apt update -qq 2>/dev/null
apt list --upgradable 2>/dev/null | grep -i securi
apt list --upgradable 2>/dev/null | wc -l
```

### B4. Sudo users
```bash
grep -r NOPASSWD /etc/sudoers /etc/sudoers.d/ 2>/dev/null
getent group sudo
```

### B5. Fail2ban
```bash
systemctl is-active fail2ban 2>/dev/null
systemctl is-enabled fail2ban 2>/dev/null
dpkg -l fail2ban 2>/dev/null | grep ^ii
```

### B6. Unattended upgrades
```bash
dpkg -l unattended-upgrades 2>/dev/null | grep ^ii
systemctl is-active unattended-upgrades 2>/dev/null
```

---

## C. System Health

### C1. Kernel
```bash
uname -r
dpkg -l 'linux-image-*' 2>/dev/null | grep ^ii | tail -3
```

### C2. Disk space
```bash
df -h | grep -E "^/dev"
```

### C3. SMART
```bash
sudo smartctl -H /dev/sda 2>/dev/null || echo "smartmontools not installed"
```

### C4. Memory
```bash
free -h
```

### C5. Failed services
```bash
systemctl --failed --no-pager
```

### C6. Docker
```bash
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null
docker system df 2>/dev/null
```

### C7. Timers
```bash
systemctl list-timers --failed --no-pager 2>/dev/null
```

### C8. Backups
```bash
ls -ldt /backup/*/ 2>/dev/null
BACKUP_COUNT=$(ls -d /backup/*/ 2>/dev/null | wc -l)
LATEST=$(ls -dt /backup/*/ 2>/dev/null | head -1)
LATEST_AGE=$(( ($(date +%s) - $(stat -c %Y "$LATEST" 2>/dev/null || echo 0)) / 86400 ))
echo "Backups: $BACKUP_COUNT, latest: $LATEST ($LATEST_AGE days old)"
```

---

## Severity Classification

| Level | Meaning | Examples |
|---|---|---|
| Critical | Active breakage or exploit risk | Runtime shadowing, SSH root+password |
| High | Security gap, needs fix soon | No firewall, no fail2ban, pending security patches |
| Medium | Suboptimal, plan a fix | Orphaned runtime dirs, stopped Docker containers |
| Low | Improvement opportunity | Missing version manager, old backup |
| Info | Documentation only | System state snapshot, configuration note |
