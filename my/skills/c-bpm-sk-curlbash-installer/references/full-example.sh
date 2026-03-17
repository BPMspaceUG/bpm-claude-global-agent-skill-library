# Full Example: mytool + install.sh
#
# A complete minimal tool with versioning, ready to copy and adapt.
# Reference for: c-bpm-sk-curlbash-installer skill

## mytool (the script)

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

## install.sh (the installer)

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
