---
model: opus
name: my-curlbash-installer
description: Pattern for curl|bash installation, update, and uninstall scripts supporting system-wide and user-level installs. Use when distributing CLI tools, creating installers, or building update mechanisms. Derived from S03.
---

# curl|bash Installer

Pattern for creating installation, update and uninstall scripts invokable via `curl | bash`, supporting both system-wide and user-level installations with version checks.

## Checklist

- [ ] User-friendly usage description and flags (`--system`, `--user`)
- [ ] OS and architecture detection if necessary
- [ ] Install paths: `/usr/local/bin` + `/etc/<tool>` (system) or `~/.local/bin` + `~/.config/<tool>` (user)
- [ ] Prerequisite checks (curl, git, unzip) with informative abort
- [ ] Download/clone to temporary directory
- [ ] Compare current vs new version
- [ ] Install/upgrade with correct permissions
- [ ] Uninstall script or flag
- [ ] Idempotent updates
- [ ] Checksum or signature verification where feasible

## Template

```bash
install_tool() {
  local install_mode="$1" # system or user
  # determine prefix based on mode
  # download archive or clone repository
  # extract and copy files
}
case "$1" in
  --system) install_tool "system";;
  --user)   install_tool "user";;
  *)        install_tool "user";;
esac
```

## Success Criteria

- Installer works without errors for both modes
- Users can choose between system and user installation
- Uninstall removes all artefacts cleanly
- Re-running with same version is a no-op

## Common Failure Modes

- Hardcoded paths or permission errors
- Missing dependency checks
- Assuming root privileges unnecessarily
