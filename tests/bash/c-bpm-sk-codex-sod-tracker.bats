#!/usr/bin/env bats
#
# c-bpm-sk-codex-sod-tracker.bats - repo-confined, per-session SoD tracker (#168, #86)
# Run with: bats tests/bash/c-bpm-sk-codex-sod-tracker.bats
#
# Fixture repos MUST live outside /tmp: the tracker excludes /tmp/* on purpose,
# so a fixture repo rooted under /tmp would have its own tracked files wrongly
# excluded, breaking the very tests meant to prove tracking works.

setup() {
  BASE="$(mktemp -d "$HOME/.cache/sodtest.XXXXXX")"
  SREPO="$BASE/session"
  OREPO="$BASE/other"
  mkdir -p "$SREPO" "$OREPO"

  git -C "$SREPO" init -q
  git -C "$SREPO" config user.email t@t
  git -C "$SREPO" config user.name t
  printf 'x\n' > "$SREPO/src.txt"
  git -C "$SREPO" add src.txt
  git -C "$SREPO" commit -qm init

  git -C "$OREPO" init -q
  git -C "$OREPO" config user.email t@t
  git -C "$OREPO" config user.name t
  printf 'y\n' > "$OREPO/other.txt"
  git -C "$OREPO" add other.txt
  git -C "$OREPO" commit -qm init

  TRACKER="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/my/hooks/codex-sod-tracker.sh"
}

teardown() {
  rm -rf "$BASE" /tmp/claude-codex-sod/t* /tmp/claude-codex-sod/g*
}

_edit() { # file cwd sid
  jq -n --arg f "$1" --arg c "$2" --arg s "$3" '{tool_input:{file_path:$f},cwd:$c,session_id:$s}' \
    | bash "$TRACKER" POST_EDIT >/dev/null 2>&1
}
_logfile() { echo "/tmp/claude-codex-sod/$1/changed_files.log"; }
_has() { [ -f "$(_logfile "$1")" ] && grep -qF "$(realpath -m -- "$2")" "$(_logfile "$1")"; }

@test "[#86] tracks a git-tracked file inside the session repo" {
  _edit "$SREPO/src.txt" "$SREPO" t1
  _has t1 "$SREPO/src.txt"
}

@test "[#168] does NOT track a file in a different repo" {
  _edit "$OREPO/other.txt" "$SREPO" t2
  ! _has t2 "$OREPO/other.txt"
}

@test "[#86] does NOT track a memory file" {
  _edit "$HOME/.claude/projects/x/memory/m.md" "$SREPO" t3
  ! _has t3 "$HOME/.claude/projects/x/memory/m.md"
}

@test "[#86] does NOT track a /tmp file" {
  _edit "/tmp/scratch_$$.txt" "$SREPO" t4
  ! _has t4 "/tmp/scratch_$$.txt"
}

@test "[#86] does NOT track a per-host inventory file" {
  mkdir -p "$SREPO/my/hosts/h"
  printf a > "$SREPO/my/hosts/h/agents.txt"
  git -C "$SREPO" add -A
  git -C "$SREPO" commit -qm inv
  _edit "$SREPO/my/hosts/h/agents.txt" "$SREPO" t5
  ! _has t5 "$SREPO/my/hosts/h/agents.txt"
}

@test "[#86] does NOT track a MEMORY.md" {
  mkdir -p "$SREPO/sub"
  printf a > "$SREPO/sub/MEMORY.md"
  git -C "$SREPO" add -A
  git -C "$SREPO" commit -qm mem
  _edit "$SREPO/sub/MEMORY.md" "$SREPO" t6
  ! _has t6 "$SREPO/sub/MEMORY.md"
}

@test "[#86] does NOT track an untracked-new file" {
  printf a > "$SREPO/scratch.txt"
  _edit "$SREPO/scratch.txt" "$SREPO" t7
  ! _has t7 "$SREPO/scratch.txt"
}

@test "[#168] two sessions get isolated dirs" {
  _edit "$SREPO/src.txt" "$SREPO" tA
  _edit "$SREPO/src.txt" "$SREPO" tB
  _has tA "$SREPO/src.txt"
  _has tB "$SREPO/src.txt"
  [ "$(_logfile tA)" != "$(_logfile tB)" ]
  rm -rf /tmp/claude-codex-sod/tA /tmp/claude-codex-sod/tB
}

@test "[#168] STOP removes only its own session dir" {
  _edit "$SREPO/src.txt" "$SREPO" tA
  _edit "$SREPO/src.txt" "$SREPO" tB
  echo '{"session_id":"tA"}' | bash "$TRACKER" STOP >/dev/null
  [ ! -d /tmp/claude-codex-sod/tA ]
  [ -d /tmp/claude-codex-sod/tB ]
  rm -rf /tmp/claude-codex-sod/tB
}

@test "[#168] session_id sanitized against traversal" {
  _edit "$SREPO/src.txt" "$SREPO" '../evil'
  [ ! -e /tmp/claude-codex-evil ]
  [ ! -e /tmp/claude-codex-sod/../evil ]
  rm -rf /tmp/claude-codex-sod/evil
}

@test "[#168] non-git cwd tracks nothing" {
  _edit "$SREPO/src.txt" "/tmp" t11
  ! _has t11 "$SREPO/src.txt"
}

@test "[#86] SessionStart text reworded" {
  out="$(echo '{"session_id":"t12"}' | bash "$TRACKER" SESSION_START)"
  [[ "$out" == *"code change in a git-tracked repo"* ]]
  [[ "$out" == *"phase transitions"* ]]
  [[ "$out" != *"Every file change is reviewed by the Team Lead before it lands"* ]]
}

@test "[#86] symlink resolving outside the repo is NOT tracked" {
  ln -s "$OREPO/other.txt" "$SREPO/link.txt"
  _edit "$SREPO/link.txt" "$SREPO" t13
  ! _has t13 "$SREPO/link.txt"
}

@test "[#86] POST_EDIT exits 0 even for an untrackable file" {
  run bash -c 'jq -n --arg f "/tmp/nope.txt" --arg c "/tmp" --arg s "t14" \
    "{tool_input:{file_path:\$f},cwd:\$c,session_id:\$s}" | bash "'"$TRACKER"'" POST_EDIT'
  [ "$status" -eq 0 ]
}

@test "[#80] a Bash command containing 'codex exec' marks nothing and makes no compliance claim" {
  _edit "$SREPO/src.txt" "$SREPO" g1
  out="$(echo '{"tool_input":{"command":"echo codex exec"},"session_id":"g1"}' | bash "$TRACKER" POST_BASH)"
  [ "$out" = '{}' ]
  stop="$(echo '{"session_id":"g1"}' | bash "$TRACKER" STOP)"
  echo "$stop" | grep -qvF 'SoD compliant' || { echo "STOP still claims compliant"; return 1; }
  ! echo "$stop" | grep -qF 'SoD compliant'
  ! echo "$stop" | grep -qF 'without Codex review'
}

@test "[#80] STOP output is neutral telemetry (no false compliance)" {
  _edit "$SREPO/src.txt" "$SREPO" g2
  stop="$(echo '{"session_id":"g2"}' | bash "$TRACKER" STOP)"
  echo "$stop" | grep -qF 'changed this session'
  ! echo "$stop" | grep -qF 'SoD compliant'
  ! echo "$stop" | grep -qF 'without Codex review'
}

@test "[#80] POST_EDIT tracking is decoupled from POST_BASH content (arbitrary + codex-exec both inert)" {
  _edit "$SREPO/src.txt" "$SREPO" g3
  echo '{"tool_input":{"command":"ls -la"},"session_id":"g3"}' | bash "$TRACKER" POST_BASH >/dev/null
  echo '{"tool_input":{"command":"echo codex exec now"},"session_id":"g3"}' | bash "$TRACKER" POST_BASH >/dev/null
  _has g3 "$SREPO/src.txt"
}

@test "[#80] POST_BASH is unconditionally inert (arbitrary command yields {})" {
  out="$(echo '{"tool_input":{"command":"true"},"session_id":"g4"}' | bash "$TRACKER" POST_BASH)"
  [ "$out" = '{}' ]
}
