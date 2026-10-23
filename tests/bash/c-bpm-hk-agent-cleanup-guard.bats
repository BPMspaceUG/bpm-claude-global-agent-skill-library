#!/usr/bin/env bats
#
# c-bpm-hk-agent-cleanup-guard.bats — behaviour of the agent cleanup hook and
# of its installation by c-bpm-cm-library-pull (lib.sh install_c_bpm_hooks).
#
# Hook contract verified against https://code.claude.com/docs/en/hooks.md
# (fetched 2026-10-23):
#   TeammateIdle: exit 2 makes the TEAMMATE keep working (the old guard did
#     that, which kept every teammate alive); JSON {"continue": false} stops
#     the teammate entirely.
#   Stop: input carries background_tasks[{id,type,status,description,...}]
#     and stop_hook_active; hookSpecificOutput.additionalContext keeps the
#     conversation going as non-error feedback; stop_hook_active=true means
#     Claude is already continuing because of a stop hook.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
HOOK="${REPO_ROOT}/my/hooks/c-bpm-hk-agent-cleanup-guard.sh"
FRAGMENT="${REPO_ROOT}/my/hooks/c-bpm-hooks.json"

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="${TEST_HOME}"
  mkdir -p "${HOME}/.claude/hooks"
}

teardown() {
  rm -rf "${TEST_HOME}"
}

hook() { # <mode> <json>
  run bash -c 'printf "%s" "$2" | "$1" "$3"' _ "${HOOK}" "$2" "$1"
}

# ------------------------------------------------------------------
# the hook itself
# ------------------------------------------------------------------

@test "hook: exists, is executable and parses" {
  [ -x "${HOOK}" ]
  bash -n "${HOOK}"
}

@test "TeammateIdle: stops the teammate with continue:false and never exits 2" {
  hook idle '{"hook_event_name":"TeammateIdle","teammate_name":"src-refs","session_id":"s1"}'
  [ "${status}" -eq 0 ]
  [ "$(printf '%s' "${output}" | jq -r '.continue')" = "false" ]
  [[ "$(printf '%s' "${output}" | jq -r '.stopReason')" == *src-refs* ]]
}

@test "SessionStart: injects the agent sweep as additionalContext" {
  hook start '{"hook_event_name":"SessionStart","session_id":"s1"}'
  [ "${status}" -eq 0 ]
  [ "$(printf '%s' "${output}" | jq -r '.hookSpecificOutput.hookEventName')" = "SessionStart" ]
  [[ "$(printf '%s' "${output}" | jq -r '.hookSpecificOutput.additionalContext')" == *"AGENT SWEEP REQUIRED"* ]]
}

@test "Stop: nothing in flight -> no output, exit 0" {
  hook stop '{"hook_event_name":"Stop","stop_hook_active":false,"background_tasks":[]}'
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}

@test "Stop: harness monitors alone are ignored" {
  hook stop '{"hook_event_name":"Stop","stop_hook_active":false,"background_tasks":[{"id":"m1","type":"monitor","status":"running","description":"live updates for artifact"}]}'
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}

@test "Stop: open teammate and shell -> one continuation naming each id, plus a visible status line" {
  hook stop '{"hook_event_name":"Stop","stop_hook_active":false,"background_tasks":[
    {"id":"t2yu6jjq2","type":"teammate","status":"running","description":"Register FitSM sources"},
    {"id":"bkl7q59o8","type":"shell","status":"running","description":"Wait until files exist","command":"until false; do sleep 5; done"},
    {"id":"m1","type":"monitor","status":"running","description":"artifact"}]}'
  [ "${status}" -eq 0 ]
  local ctx msg
  ctx="$(printf '%s' "${output}" | jq -r '.hookSpecificOutput.additionalContext')"
  msg="$(printf '%s' "${output}" | jq -r '.systemMessage')"
  [ "$(printf '%s' "${output}" | jq -r '.hookSpecificOutput.hookEventName')" = "Stop" ]
  [[ "${ctx}" == *t2yu6jjq2* ]]
  [[ "${ctx}" == *bkl7q59o8* ]]
  [[ "${ctx}" == *TaskStop* ]]
  [[ "${ctx}" != *m1* ]]
  [[ "${msg}" == *"1 teammate"* ]]
  [[ "${msg}" == *"1 shell"* ]]
}

@test "Stop: a running subagent is shown to the user but does not force a continuation" {
  hook stop '{"hook_event_name":"Stop","stop_hook_active":false,"background_tasks":[{"id":"a688","type":"subagent","status":"running","description":"Spec review","agent_type":"general-purpose"}]}'
  [ "${status}" -eq 0 ]
  [ "$(printf '%s' "${output}" | jq -r '.hookSpecificOutput // empty')" = "" ]
  [[ "$(printf '%s' "${output}" | jq -r '.systemMessage')" == *"1 subagent"* ]]
}

@test "Stop: stop_hook_active=true never continues again (no loop), but still shows the status" {
  hook stop '{"hook_event_name":"Stop","stop_hook_active":true,"background_tasks":[{"id":"t1","type":"teammate","status":"running","description":"x"}]}'
  [ "${status}" -eq 0 ]
  [ "$(printf '%s' "${output}" | jq -r '.hookSpecificOutput // empty')" = "" ]
  [ "$(printf '%s' "${output}" | jq -r '.decision // empty')" = "" ]
  [[ "$(printf '%s' "${output}" | jq -r '.systemMessage')" == *"1 teammate"* ]]
}

@test "Stop: payload without background_tasks (older Claude Code) -> exit 0, no output" {
  hook stop '{"hook_event_name":"Stop","stop_hook_active":false}'
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}

@test "hook log is capped and lives under ~/.claude/hooks" {
  head -c 300000 /dev/zero | tr '\0' 'x' > "${HOME}/.claude/hooks/c-bpm-hk-agent-cleanup-guard.log"
  hook stop '{"hook_event_name":"Stop","stop_hook_active":false,"background_tasks":[]}'
  [ "$(wc -c < "${HOME}/.claude/hooks/c-bpm-hk-agent-cleanup-guard.log")" -lt 262144 ]
}

# ------------------------------------------------------------------
# installation via lib.sh
# ------------------------------------------------------------------

install_hooks() {
  run bash -c 'DRY_RUN=0; VERBOSE=0; source "$1/lib.sh"; install_c_bpm_hooks "$1" "$HOME/.claude"' _ "${REPO_ROOT}"
}

events_with_guard() { # <settings file>
  jq -r '.hooks | to_entries[] | select([.value[].hooks[].command] | any(contains("c-bpm-hk-agent-cleanup-guard.sh"))) | .key' "$1" | sort | tr '\n' ' '
}

@test "fragment: registers exactly SessionStart, Stop, TeammateIdle and points at installed c-bpm-hk scripts" {
  [ "$(jq -r 'keys | sort | join(" ")' "${FRAGMENT}")" = "SessionStart Stop TeammateIdle" ]
  ! jq -r '.. | .command? // empty' "${FRAGMENT}" | grep -vqE '^~/\.claude/hooks/c-bpm-hk-[a-z-]+\.sh [a-z]+$'
  local s; for s in $(jq -r '.. | .command? // empty' "${FRAGMENT}" | awk '{print $1}' | sed 's|^~/.claude/hooks/||' | sort -u); do
    [ -x "${REPO_ROOT}/my/hooks/${s}" ] || { echo "fragment names missing script ${s}" >&2; return 1; }
  done
}

@test "install: copies the hook, registers three events, keeps unrelated settings" {
  printf '{"model":"x","hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"other-hook"}]}]}}' > "${HOME}/.claude/settings.json"
  install_hooks
  [ "${status}" -eq 0 ] || { echo "${output}" >&2; return 1; }
  [ -x "${HOME}/.claude/hooks/c-bpm-hk-agent-cleanup-guard.sh" ]
  [ "$(events_with_guard "${HOME}/.claude/settings.json")" = "SessionStart Stop TeammateIdle " ]
  [ "$(jq -r '.model' "${HOME}/.claude/settings.json")" = "x" ]
  [ "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "${HOME}/.claude/settings.json")" = "other-hook" ]
}

@test "install: idempotent — a second run adds no duplicate entry" {
  printf '{}' > "${HOME}/.claude/settings.json"
  install_hooks; install_hooks
  [ "${status}" -eq 0 ]
  [ "$(jq '[.hooks[][].hooks[] | select(.command | contains("c-bpm-hk-agent-cleanup-guard.sh"))] | length' "${HOME}/.claude/settings.json")" -eq 3 ]
}

@test "install: replaces the legacy agent-cleanup-guard.sh registrations (incl. TaskCompleted) and removes the legacy file" {
  printf '#!/bin/sh\n' > "${HOME}/.claude/hooks/agent-cleanup-guard.sh"
  printf '{"hooks":{"TaskCompleted":[{"hooks":[{"type":"command","command":"~/.claude/hooks/agent-cleanup-guard.sh idle"}]}],"Stop":[{"hooks":[{"type":"command","command":"~/.claude/hooks/agent-cleanup-guard.sh stop"},{"type":"command","command":"keep-me"}]}]}}' > "${HOME}/.claude/settings.json"
  install_hooks
  [ "${status}" -eq 0 ]
  ! grep -q 'agent-cleanup-guard.sh idle\|agent-cleanup-guard.sh stop' "${HOME}/.claude/settings.json"
  [ "$(jq -r '.hooks.TaskCompleted // "gone"' "${HOME}/.claude/settings.json")" = "gone" ]
  grep -q 'keep-me' "${HOME}/.claude/settings.json"
  [ ! -e "${HOME}/.claude/hooks/agent-cleanup-guard.sh" ]
}

@test "install: creates ~/.claude/settings.json when missing, skips a missing ~/.config/claude/settings.json" {
  install_hooks
  [ "${status}" -eq 0 ]
  [ -f "${HOME}/.claude/settings.json" ]
  [ ! -e "${HOME}/.config/claude/settings.json" ]
}

@test "install: dry run writes nothing" {
  printf '{}' > "${HOME}/.claude/settings.json"
  run bash -c 'DRY_RUN=1; VERBOSE=0; source "$1/lib.sh"; install_c_bpm_hooks "$1" "$HOME/.claude"' _ "${REPO_ROOT}"
  [ "${status}" -eq 0 ]
  [ "$(cat "${HOME}/.claude/settings.json")" = "{}" ]
  [ ! -e "${HOME}/.claude/hooks/c-bpm-hk-agent-cleanup-guard.sh" ]
}

# ------------------------------------------------------------------
# skill-rules.json is dead and gets removed
# ------------------------------------------------------------------

@test "skill-rules: lib.sh no longer generates it" {
  ! grep -q 'generate_skill_rules_json' "${REPO_ROOT}/lib.sh" "${REPO_ROOT}/sync" "${REPO_ROOT}/c-bpm-cm-library-pull"
}

@test "skill-rules: the generated legacy file is removed, a foreign one is kept" {
  mkdir -p "${HOME}/.claude/skills"
  printf '{"description":"Skill activation triggers for Claude Code. Auto-generated by c-bpm-cm-library-pull."}' > "${HOME}/.claude/skills/skill-rules.json"
  run bash -c 'DRY_RUN=0; VERBOSE=0; source "$1/lib.sh"; remove_legacy_skill_rules "$HOME/.claude"' _ "${REPO_ROOT}"
  [ "${status}" -eq 0 ]
  [ ! -e "${HOME}/.claude/skills/skill-rules.json" ]
  printf '{"description":"mine"}' > "${HOME}/.claude/skills/skill-rules.json"
  run bash -c 'DRY_RUN=0; VERBOSE=0; source "$1/lib.sh"; remove_legacy_skill_rules "$HOME/.claude"' _ "${REPO_ROOT}"
  [ -e "${HOME}/.claude/skills/skill-rules.json" ]
}

# ------------------------------------------------------------------
# review round 1 (2026-10-23)
# ------------------------------------------------------------------

@test "fragment: the sweep fires only on startup and /clear, never on compact or resume" {
  [ "$(jq -r '.SessionStart[0].matcher' "${FRAGMENT}")" = "startup|clear" ]
}

@test "TeammateIdle: still stops the teammate when jq is missing" {
  local bin; bin="$(mktemp -d)"
  local t; for t in bash cat date tr wc tail mv printf; do
    [ -x "$(command -v "${t}")" ] && ln -s "$(command -v "${t}")" "${bin}/${t}"
  done
  run env PATH="${bin}" bash -c 'printf "%s" "{\"teammate_name\":\"x\"}" | "$1" idle' _ "${HOOK}"
  rm -rf "${bin}"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *'"continue": false'* ]]
}

@test "hook log never stores last_assistant_message" {
  hook stop '{"hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"SECRET-TEXT","background_tasks":[]}'
  ! grep -q 'SECRET-TEXT' "${HOME}/.claude/hooks/c-bpm-hk-agent-cleanup-guard.log"
}

@test "install: the script always lands in ~/.claude/hooks, even when the target dir is ~/.config/claude" {
  mkdir -p "${HOME}/.config/claude"; printf '{}' > "${HOME}/.config/claude/settings.json"
  run bash -c 'DRY_RUN=0; VERBOSE=0; source "$1/lib.sh"; install_c_bpm_hooks "$1" "$HOME/.config/claude"' _ "${REPO_ROOT}"
  [ "${status}" -eq 0 ] || { echo "${output}" >&2; return 1; }
  [ -x "${HOME}/.claude/hooks/c-bpm-hk-agent-cleanup-guard.sh" ]
  [ "$(events_with_guard "${HOME}/.config/claude/settings.json")" = "SessionStart Stop TeammateIdle " ]
}

@test "install: keeps non-ASCII text in settings.json verbatim" {
  printf '{"statusLine":{"text":"Übersicht ✓"}}' > "${HOME}/.claude/settings.json"
  install_hooks
  [ "${status}" -eq 0 ]
  grep -q 'Übersicht ✓' "${HOME}/.claude/settings.json"
}

@test "install: warns when jq is not installed" {
  grep -q 'jq' "${REPO_ROOT}/lib.sh"
  run bash -c 'source "$1/lib.sh"; type install_c_bpm_hooks' _ "${REPO_ROOT}"
  [[ "${output}" == *"command -v jq"* ]]
}

@test "lib.sh: the dead parse_frontmatter_field is gone" {
  ! grep -q 'parse_frontmatter_field' "${REPO_ROOT}/lib.sh"
}

@test "gogo teammate contract: blocking work runs in the foreground because idle teammates are stopped" {
  grep -qF 'Run tests and Codex in the foreground' "${REPO_ROOT}/my/skills/c-bpm-sk-gogo/TEAMMATE.md"
}
