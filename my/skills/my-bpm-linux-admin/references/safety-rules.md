# Safety Rules — NON-NEGOTIABLE

Every admin teammate MUST follow these rules. Violation = immediate rollback + rejection.

---

## SSH Protection

```bash
# BEFORE changing /etc/ssh/sshd_config:
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)

# AFTER editing, BEFORE restarting:
sudo sshd -t  # Must return success

# Verify SSH port is allowed in firewall:
sudo ufw status | grep -E "22|ssh"

# ONLY THEN restart:
sudo systemctl restart sshd
```

**NEVER** disable PubkeyAuthentication.
**NEVER** change the SSH port without adding the new port to firewall FIRST.

---

## Firewall Protection

```bash
# BEFORE enabling UFW:
sudo ufw allow ssh  # ALWAYS first

# Preview changes:
sudo ufw show added  # Check what will be applied

# Verify after changes:
sudo ufw status verbose
```

**NEVER** run `ufw enable` without `ufw allow ssh` first.
**NEVER** run `ufw reset` on a remote server.
**NEVER** delete the SSH allow rule.

---

## Service Protection

```bash
# BEFORE restarting any service, validate config:
sudo nginx -t           # nginx
sudo sshd -t            # SSH
sudo named-checkconf    # BIND
sudo apachectl configtest  # Apache

# AFTER restart, check status:
sudo systemctl status <service>
sudo journalctl -u <service> --no-pager -n 20
```

**NEVER** stop a service without checking dependents:
```bash
systemctl list-dependencies --reverse <service>
```

---

## Package Protection

```bash
# BEFORE removing any package:
apt-cache rdepends --installed <package>
apt-get -s remove <package>  # simulate

# BEFORE major upgrades:
sudo apt-get -s dist-upgrade  # simulate first
```

**NEVER** use `--force-yes` or `--allow-downgrades` without explicit user approval.
**NEVER** remove `openssh-server`, `sudo`, `systemd`, or `apt`.

---

## Data Protection

```bash
# ALWAYS backup before modifying config files:
sudo cp /etc/<file> /etc/<file>.bak.$(date +%Y%m%d)

# BEFORE deleting Docker volumes:
docker volume inspect <volume>  # Check if referenced
docker ps -a --filter "volume=<volume>"  # Check container usage

# BEFORE deleting files:
lsof <file> 2>/dev/null  # Check if in use
```

**NEVER** run `rm -rf /` or any recursive delete on system directories.
**NEVER** truncate log files without checking if a service writes to them actively.

---

## Network Protection

```bash
# BEFORE changing iptables/nftables:
sudo iptables -L -n  # Document current state
sudo iptables-save > /tmp/iptables-backup.$(date +%Y%m%d)

# Docker + UFW awareness:
# Docker bypasses UFW by inserting DOCKER chain rules
# Use ufw-docker or DOCKER-USER chain for Docker port control
```

**NEVER** flush iptables without ensuring SSH access is preserved.

---

## Rollback Patterns

### Config file rollback
```bash
sudo cp /etc/<file>.bak.<date> /etc/<file>
sudo systemctl restart <service>
```

### Package rollback
```bash
sudo apt-get install <package>  # reinstall removed package
```

### Firewall rollback
```bash
sudo ufw disable  # emergency: disable firewall entirely
# Then re-enable with correct rules
```

### Service rollback
```bash
sudo systemctl start <service>  # restart stopped service
sudo journalctl -u <service> -f  # watch logs
```
