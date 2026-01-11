# Skill S03 – Install & Update Standard (curl|bash, System vs User)

## Goal

Provide a pattern for creating installation, update and uninstall scripts that can be invoked via `curl | bash`. These scripts should support both system‑wide and user‑level installations and include version checks for upgrades.

## When to Use

- When distributing a CLI tool or library that needs to be installed on target machines.
- When updating an existing tool to a new version.
- When removing installed components cleanly.

## Checklist

- [ ] Include a user‑friendly usage description and flags (`--system`, `--user`).
- [ ] Detect the operating system and architecture if necessary.
- [ ] Determine installation paths: `/usr/local/bin` and `/etc/<tool>` for system‑wide, or `~/.local/bin` and `~/.config/<tool>` for user installations.
- [ ] Verify prerequisites (e.g. `curl`, `git`, `unzip`) and abort with an informative message if missing.
- [ ] Download or clone the tool into a temporary directory.
- [ ] Compare current installed version (if any) with the new version.
- [ ] Install or upgrade files with correct permissions.
- [ ] Provide an `uninstall` script or flag to remove installed files.
- [ ] Handle updates idempotently; avoid duplicate installation.
- [ ] Support checksums or signatures where feasible to verify downloads.

## Minimal Snippets

```
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

- Running the installer script installs or updates the tool without errors.
- Users can choose between system and user installation.
- Uninstalling removes all installed artefacts cleanly.
- Re‑running the installer with the same version does nothing.

## Common Failure Modes

- Hardcoded paths or permission errors.
- Missing dependency checks.
- Scripts that assume root privileges unnecessarily.