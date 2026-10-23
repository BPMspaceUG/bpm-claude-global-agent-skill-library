#!/usr/bin/env bash
# c-bpm-hk-skills-refresh.sh — keep Matt Pocock's skills and this library current,
# and keep every Pocock skill callable by the model.
#
# Pocock's plugin (mattpocock-skills@mattpocock) ships most skills with
# `disable-model-invocation: true`; Claude then cannot call to-spec, to-tickets,
# implement-spec, retro, ... on its own. Every plugin update restores that line
# in the installed copy, so the unlock is re-applied after each update.
#
# Modes:
#   hook    SessionStart (startup|resume). Unlocks locally and synchronously (no
#           network), then — at most once per interval, failures included —
#           starts a detached worker and returns. Prints nothing.
#   worker  Plugin update, unlock, c-bpm-cm-library-pull. One at a time (lock).
#           Output goes to the log. Takes effect in the NEXT session.
#   check   Table: installed version, upstream version, locked skills.
#   unlock  Unlock only, no network. Table.
#   update  Plugin update + unlock. Table. Used by /c-bpm-cm-pocock-update.
#
# Never edits the plugin's marketplace git clone; only the installed cache copy.
# Deliberately no `set -e`: hook mode must always exit 0.

set -uo pipefail

MODE="${1:-check}"
PLUGIN="mattpocock-skills@mattpocock"
MANIFEST_URL="${POCOCK_MANIFEST_URL:-https://raw.githubusercontent.com/mattpocock/skills/main/.claude-plugin/plugin.json}"
CLAUDE_BIN="${C_BPM_CLAUDE_BIN:-claude}"
PULL_BIN="${C_BPM_PULL_BIN:-c-bpm-cm-library-pull}"
INTERVAL="${C_BPM_REFRESH_INTERVAL:-86400}"
INSTALLED_JSON="${HOME}/.claude/plugins/installed_plugins.json"
STATE_DIR="${HOME}/.claude/hooks/c-bpm-hk-skills-refresh.d"
LOG="${HOME}/.claude/hooks/c-bpm-hk-skills-refresh.log"
LOCK_RE='^disable-model-invocation:[[:space:]]*true'

installed_field() { # <field>
  [ -f "$INSTALLED_JSON" ] || return 0
  python3 -I - "$INSTALLED_JSON" "$PLUGIN" "$1" <<'PY' 2>/dev/null
import json, sys
path, plugin, field = sys.argv[1:4]
d = json.load(open(path))
entries = d.get("plugins", d).get(plugin, [])
print(entries[0].get(field, "") if entries else "")
PY
}

require_plugin() {
  INSTALL_PATH="$(installed_field installPath)"
  if [ -z "$INSTALL_PATH" ] || [ ! -d "$INSTALL_PATH/skills" ]; then
    echo "ERROR: $PLUGIN is not installed — run: claude plugin install $PLUGIN" >&2
    return 1
  fi
}

locked_files() {
  { grep -rlE "$LOCK_RE" "$INSTALL_PATH/skills" 2>/dev/null || true; } | sort
}

# Remove the lock line from the frontmatter of each locked SKILL.md.
# Sets UNLOCKED (array of skill names).
unlock_all() {
  UNLOCKED=()
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    python3 -I - "$f" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
m = re.match(r'^---\n(.*?)\n---\n', s, re.S)
if m:
    fm = re.sub(r'^disable-model-invocation:[ \t]*true[ \t]*\n', '', m.group(1) + "\n", flags=re.M)
    open(p, "w", encoding="utf-8").write("---\n" + fm.rstrip("\n") + "\n---\n" + s[m.end():])
PY
    UNLOCKED+=("$(basename "$(dirname "$f")")")
  done < <(locked_files)
}

upstream_version() {
  curl -fsSL --max-time 10 "$MANIFEST_URL" 2>/dev/null \
    | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["version"])' 2>/dev/null || echo unknown
}

plugin_update() { # sets UPDATE_RESULT
  local out
  if out="$(timeout 180 "$CLAUDE_BIN" plugin update -y "$PLUGIN" </dev/null 2>&1)"; then
    UPDATE_RESULT="ok"
  else
    UPDATE_RESULT="failed — $(printf '%s' "$out" | tail -1 | cut -c1-120)"
  fi
}

table_row() { printf '| %s | %s |\n' "$1" "$2"; }

report() { # <before-version>
  local remaining total
  remaining="$(locked_files | wc -l)"
  total="$(find "$INSTALL_PATH/skills" -name SKILL.md | wc -l)"
  printf '| Field | Value |\n|---|---|\n'
  table_row "version before" "$1"
  table_row "version after" "$(installed_field version)"
  table_row "plugin update" "${UPDATE_RESULT:-skipped}"
  table_row "install path" "$INSTALL_PATH"
  table_row "skills total" "$total"
  table_row "unlocked this run" "${#UNLOCKED[@]}"
  table_row "still locked" "$remaining"
  [ "${#UNLOCKED[@]}" -eq 0 ] || printf '\nUnlocked: %s\n' "${UNLOCKED[*]}"
  [ "$remaining" -eq 0 ]
}

cap_log() {
  mkdir -p "$(dirname "$LOG")"
  if [ -f "$LOG" ] && [ "$(wc -c <"$LOG")" -gt 262144 ]; then
    tail -c 131072 "$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  fi
}

case "$MODE" in
  check)
    require_plugin || exit 1
    printf '| Field | Value |\n|---|---|\n'
    table_row "installed version" "$(installed_field version)"
    table_row "upstream version" "$(upstream_version)"
    table_row "locked skills" "$(locked_files | wc -l)"
    ;;

  unlock)
    require_plugin || exit 1
    before="$(installed_field version)"
    unlock_all
    report "$before" || exit 1
    ;;

  update)
    require_plugin || exit 1
    before="$(installed_field version)"
    plugin_update
    require_plugin || exit 1   # install path changes with the version
    unlock_all
    report "$before" || exit 1
    echo
    echo "Restart Claude Code to load the updated plugin."
    ;;

  worker)
    cap_log
    mkdir -p "$STATE_DIR"
    exec 9>"$STATE_DIR/lock"
    flock -n 9 || exit 0
    {
      echo "=== $(date -Is) worker start"
      if require_plugin; then
        before="$(installed_field version)"
        plugin_update
        require_plugin && { unlock_all; report "$before"; }
      fi
      echo "--- library pull"
      GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=15" \
        timeout 300 "$PULL_BIN" </dev/null || echo "library pull failed (exit $?)"
      echo "=== $(date -Is) worker end"
    } >>"$LOG" 2>&1
    exit 0
    ;;

  hook)
    cat >/dev/null
    cap_log
    if require_plugin 2>/dev/null; then
      unlock_all
      [ "${#UNLOCKED[@]}" -eq 0 ] || echo "$(date -Is) hook unlocked: ${UNLOCKED[*]}" >>"$LOG"
    fi
    mkdir -p "$STATE_DIR"
    now="$(date +%s)"
    last="$(cat "$STATE_DIR/last-attempt" 2>/dev/null || echo 0)"
    case "$last" in ''|*[!0-9]*) last=0 ;; esac
    if [ $((now - last)) -ge "$INTERVAL" ]; then
      echo "$now" >"$STATE_DIR/last-attempt"
      setsid nohup bash "$0" worker </dev/null >/dev/null 2>&1 &
    fi
    exit 0
    ;;

  *)
    echo "usage: $(basename "$0") check|unlock|update|worker|hook" >&2
    exit 2
    ;;
esac
