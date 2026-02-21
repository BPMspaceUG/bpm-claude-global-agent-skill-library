---
model: opus
name: my-bpm-curlbash-installer
description: Pattern for curl|bash installation, update, and uninstall scripts with YYMMDD-HHMM versioning (dirty/draft/clean). Use when distributing CLI tools, creating installers, or building update mechanisms. Derived from S03 with BPMspace versioning from SM2/bcgasl.
---

# curl|bash Installer with YYMMDD-HHMM Versioning

Pattern for creating installation, update and uninstall scripts invokable via `curl | bash`, supporting both system-wide and user-level installations with git-aware version stamping.

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
- [ ] **Version variable with live git detection block**
- [ ] **`--version` / `-v` flag in argument parsing**
- [ ] **`stamp_version()` in install script**
- [ ] **Version displayed in tool output header**

## Versioning System

Format: **YYMMDD-HHMM** derived from git commit date.

| State | Example | Timestamp source | Meaning |
|-------|---------|-----------------|---------|
| committed + pushed | `260218-1330` | HEAD commit | Release — production-ready |
| committed + not pushed | `260218-1330-draft` | HEAD commit | Push pending |
| uncommitted changes | `260218-1655-dirty` | **install time** | Not yet committed |
| No git repo (plain copy) | `dev` | — | Not installed via install script |

### Why install time for dirty?

Uncommitted code has no commit timestamp. Using `date` at install time gives a meaningful reference for when that dirty snapshot was captured.

## Template: Live Version Detection (in the tool script)

Place near the top of the script, after `set -euo pipefail`:

```bash
# Version: YYMMDD-HHMM from HEAD commit
#   clean + pushed   → 260218-1330         (release)
#   clean + unpushed → 260218-1330-draft   (push pending)
#   uncommitted      → 260218-1655-dirty   (uncommitted changes)
# install script bakes the version string in at install time
TOOL_VERSION="dev"
_tool_dir="$(dirname "${BASH_SOURCE[0]:-$0}")"
if git -C "$_tool_dir" rev-parse --git-dir &>/dev/null; then
    TOOL_VERSION=$(git -C "$_tool_dir" log -1 --format='%cd' --date=format:'%y%m%d-%H%M' HEAD 2>/dev/null || echo "dev")
    if ! git -C "$_tool_dir" diff --quiet HEAD 2>/dev/null || ! git -C "$_tool_dir" diff --cached --quiet HEAD 2>/dev/null; then
        TOOL_VERSION="${TOOL_VERSION}-dirty"
    elif ! git -C "$_tool_dir" diff --quiet HEAD "@{upstream}" 2>/dev/null; then
        TOOL_VERSION="${TOOL_VERSION}-draft"
    fi
fi
unset _tool_dir
```

**Adapt:** Replace `TOOL_VERSION` with your tool's variable name (e.g., `SM_VERSION`, `BCGASL_VERSION`).

When run from a git repo, this detects the state live. When installed to `/usr/local/bin/`, the git check fails silently and the baked-in value stays.

## Template: stamp_version() (in the install script)

```bash
# Stamp version: dirty uses install timestamp, clean uses commit timestamp
stamp_version() {
  local target="$1"
  local varname="${2:-TOOL_VERSION}"
  local ver="" suffix=""
  if [[ -n "${SCRIPT_DIR:-}" ]] && git -C "$SCRIPT_DIR" rev-parse --git-dir &>/dev/null; then
    if ! git -C "$SCRIPT_DIR" diff --quiet HEAD 2>/dev/null || ! git -C "$SCRIPT_DIR" diff --cached --quiet HEAD 2>/dev/null; then
      ver=$(date '+%y%m%d-%H%M')
      suffix="-dirty"
    elif ! git -C "$SCRIPT_DIR" diff --quiet HEAD "@{upstream}" 2>/dev/null; then
      ver=$(git -C "$SCRIPT_DIR" log -1 --format='%cd' --date=format:'%y%m%d-%H%M' HEAD 2>/dev/null || echo "")
      suffix="-draft"
    else
      ver=$(git -C "$SCRIPT_DIR" log -1 --format='%cd' --date=format:'%y%m%d-%H%M' HEAD 2>/dev/null || echo "")
    fi
  fi
  if [[ -n "$ver" ]]; then
    sed -i "0,/^${varname}=/{s/^${varname}=.*/${varname}=\"${ver}${suffix}\"/}" "$target"
  fi
}
```

Call after copying the script to its install location:

```bash
cp "$SCRIPT_DIR/mytool" "$INSTALL_DIR/mytool"
chmod +x "$INSTALL_DIR/mytool"
stamp_version "$INSTALL_DIR/mytool" "TOOL_VERSION"
```

## Template: Install Script

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_BIN="$HOME/.local/bin"
GLOBAL_BIN="/usr/local/bin"

stamp_version() {
  local target="$1"
  local varname="${2:-TOOL_VERSION}"
  local ver="" suffix=""
  if [[ -n "${SCRIPT_DIR:-}" ]] && git -C "$SCRIPT_DIR" rev-parse --git-dir &>/dev/null; then
    if ! git -C "$SCRIPT_DIR" diff --quiet HEAD 2>/dev/null || ! git -C "$SCRIPT_DIR" diff --cached --quiet HEAD 2>/dev/null; then
      ver=$(date '+%y%m%d-%H%M')
      suffix="-dirty"
    elif ! git -C "$SCRIPT_DIR" diff --quiet HEAD "@{upstream}" 2>/dev/null; then
      ver=$(git -C "$SCRIPT_DIR" log -1 --format='%cd' --date=format:'%y%m%d-%H%M' HEAD 2>/dev/null || echo "")
      suffix="-draft"
    else
      ver=$(git -C "$SCRIPT_DIR" log -1 --format='%cd' --date=format:'%y%m%d-%H%M' HEAD 2>/dev/null || echo "")
    fi
  fi
  if [[ -n "$ver" ]]; then
    sed -i "0,/^${varname}=/{s/^${varname}=.*/${varname}=\"${ver}${suffix}\"/}" "$target"
  fi
}

install_to() {
  local dir="$1"
  local tool="mytool"
  local varname="TOOL_VERSION"

  local old_ver=""
  [[ -f "$dir/$tool" ]] && old_ver=$(grep -m1 "^${varname}=" "$dir/$tool" 2>/dev/null | cut -d'"' -f2 || echo "")

  cp "$SCRIPT_DIR/$tool" "$dir/$tool"
  chmod +x "$dir/$tool"
  stamp_version "$dir/$tool" "$varname"

  local new_ver
  new_ver=$(grep -m1 "^${varname}=" "$dir/$tool" | cut -d'"' -f2)

  if [[ -n "$old_ver" ]]; then
    if [[ "$old_ver" == "$new_ver" ]]; then
      echo "Reinstalled v${new_ver} to ${dir}"
    else
      echo "Updated ${old_ver} -> ${new_ver} in ${dir}"
    fi
  else
    echo "Installed v${new_ver} to ${dir}"
  fi
}

case "${1:-}" in
  --user)   install_to "$USER_BIN" ;;
  --global) install_to "$GLOBAL_BIN" ;;
  *)        install_to "$USER_BIN" ;;
esac
```

## Full Example: mytool + install.sh

A complete minimal tool with versioning, ready to copy and adapt.

### mytool (the script)

```bash
#!/usr/bin/env bash
# mytool - Does something useful
set -euo pipefail

# Version: YYMMDD-HHMM from HEAD commit
#   clean + pushed   → 260218-1330         (release)
#   clean + unpushed → 260218-1330-draft   (push pending)
#   uncommitted      → 260218-1655-dirty   (uncommitted changes)
# install.sh bakes the version string in at install time
MYTOOL_VERSION="dev"
_tool_dir="$(dirname "${BASH_SOURCE[0]:-$0}")"
if git -C "$_tool_dir" rev-parse --git-dir &>/dev/null; then
    MYTOOL_VERSION=$(git -C "$_tool_dir" log -1 --format='%cd' --date=format:'%y%m%d-%H%M' HEAD 2>/dev/null || echo "dev")
    if ! git -C "$_tool_dir" diff --quiet HEAD 2>/dev/null || ! git -C "$_tool_dir" diff --cached --quiet HEAD 2>/dev/null; then
        MYTOOL_VERSION="${MYTOOL_VERSION}-dirty"
    elif ! git -C "$_tool_dir" diff --quiet HEAD "@{upstream}" 2>/dev/null; then
        MYTOOL_VERSION="${MYTOOL_VERSION}-draft"
    fi
fi
unset _tool_dir

case "${1:-}" in
  --version|-v) echo "mytool $MYTOOL_VERSION"; exit 0 ;;
  --help|-h)    echo "Usage: mytool [--version|--help]"; exit 0 ;;
esac

echo "=== mytool $MYTOOL_VERSION ==="
# ... tool logic here ...
```

### install.sh (the installer)

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_BIN="$HOME/.local/bin"
GLOBAL_BIN="/usr/local/bin"

stamp_version() {
  local target="$1"
  local ver="" suffix=""
  if git -C "$SCRIPT_DIR" rev-parse --git-dir &>/dev/null; then
    if ! git -C "$SCRIPT_DIR" diff --quiet HEAD 2>/dev/null || ! git -C "$SCRIPT_DIR" diff --cached --quiet HEAD 2>/dev/null; then
      ver=$(date '+%y%m%d-%H%M')
      suffix="-dirty"
    elif ! git -C "$SCRIPT_DIR" diff --quiet HEAD "@{upstream}" 2>/dev/null; then
      ver=$(git -C "$SCRIPT_DIR" log -1 --format='%cd' --date=format:'%y%m%d-%H%M' HEAD 2>/dev/null || echo "")
      suffix="-draft"
    else
      ver=$(git -C "$SCRIPT_DIR" log -1 --format='%cd' --date=format:'%y%m%d-%H%M' HEAD 2>/dev/null || echo "")
    fi
  fi
  if [[ -n "$ver" ]]; then
    sed -i "0,/^MYTOOL_VERSION=/{s/^MYTOOL_VERSION=.*/MYTOOL_VERSION=\"${ver}${suffix}\"/}" "$target"
  fi
}

install_to() {
  local dir="$1"
  mkdir -p "$dir"

  local old_ver=""
  [[ -f "$dir/mytool" ]] && old_ver=$(grep -m1 '^MYTOOL_VERSION=' "$dir/mytool" 2>/dev/null | cut -d'"' -f2 || echo "")

  cp "$SCRIPT_DIR/mytool" "$dir/mytool"
  chmod +x "$dir/mytool"
  stamp_version "$dir/mytool"

  local new_ver
  new_ver=$(grep -m1 '^MYTOOL_VERSION=' "$dir/mytool" | cut -d'"' -f2)

  if [[ -n "$old_ver" ]]; then
    [[ "$old_ver" == "$new_ver" ]] && echo "Reinstalled v${new_ver}" || echo "Updated ${old_ver} -> ${new_ver}"
  else
    echo "Installed v${new_ver} to ${dir}"
  fi
}

case "${1:-}" in
  --user)   install_to "$USER_BIN" ;;
  --global) install_to "$GLOBAL_BIN" ;;
  *)        install_to "$USER_BIN" ;;
esac
```

## Success Criteria

- Installer works without errors for both modes
- Users can choose between system and user installation
- Uninstall removes all artefacts cleanly
- Re-running with same version is a no-op
- `--version` shows correct state (dirty/draft/clean/dev)
- Installed copy has baked-in version (no git dependency at runtime)

## Common Failure Modes

- Hardcoded paths or permission errors
- Missing dependency checks
- Assuming root privileges unnecessarily
- **Forgetting `stamp_version()` call after copy** — installed version stays `dev`
- **Using commit timestamp for dirty** — uncommitted code has no commit; use `date`
- **Wrong variable name in `sed`** — must match the exact variable in the script
- **`stamp_version` on sudo-owned file** — may need `sudo sed` for global installs
