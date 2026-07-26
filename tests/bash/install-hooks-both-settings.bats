#!/usr/bin/env bats
#
# install-hooks-both-settings.bats — integration tests for Issue #65.
#
# The defect was in the CALL, not in install-hooks: `sync` invoked
# `install-hooks` without --ensure-both, and install-hooks skips a settings
# path that does not exist unless that flag is given. On a host where only
# ~/.claude/settings.json had ever been created, ~/.config/claude/settings.json
# stayed absent and unregistered — so hooks silently did not fire for whichever
# Claude Code build reads that path.
#
# These tests drive the REAL sync end to end against a sandboxed $HOME and
# assert on the observable result: BOTH settings paths exist and BOTH carry the
# hook registration.
#
# Safety:
#   - $HOME is redirected to a temp dir for every test.
#   - sync, lib.sh, install-hooks and a fake dist/ build are copied into a temp
#     sandbox, so nothing reads or writes the working tree.
#   - INSTALL_HOOKS_SYSTEM_BIN_DIR points at an empty sandbox prefix, so the
#     per-user copy path is taken and /usr/local/bin is never touched. No test
#     here passes --system, so that seam can perform no privileged write.

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
HOOK="issue-write-gate.mjs"

setup() {
  TEST_DIR="$(mktemp -d)"

  SANDBOX="${TEST_DIR}/extracted"
  mkdir -p "${SANDBOX}/dist"
  cp "${REPO_ROOT}/sync"          "${SANDBOX}/sync"
  cp "${REPO_ROOT}/lib.sh"        "${SANDBOX}/lib.sh"
  cp "${REPO_ROOT}/install-hooks" "${SANDBOX}/install-hooks"
  chmod +x "${SANDBOX}/sync" "${SANDBOX}/install-hooks"
  printf '// sandbox dist build\n' > "${SANDBOX}/dist/${HOOK}"
  SYNC="${SANDBOX}/sync"
  INSTALL_HOOKS="${SANDBOX}/install-hooks"

  # Minimal payload so sync has something to do.
  mkdir -p "${SANDBOX}/skills" "${SANDBOX}/my/skills/c-bpm-sk-probe"
  printf 'payload\n'     > "${SANDBOX}/skills/upstream-skills.md"
  printf '# probe\n'     > "${SANDBOX}/my/skills/c-bpm-sk-probe/SKILL.md"

  # Sandbox HOME: the #65 starting state — ONLY ~/.claude/settings.json exists.
  export HOME="${TEST_DIR}/home"
  mkdir -p "${HOME}/.claude"
  printf '{}\n' > "${HOME}/.claude/settings.json"
  CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
  CONFIG_SETTINGS="${HOME}/.config/claude/settings.json"

  export INSTALL_HOOKS_SYSTEM_BIN_DIR="${TEST_DIR}/sysbin"
  mkdir -p "${INSTALL_HOOKS_SYSTEM_BIN_DIR}"
}

teardown() {
  [ -n "${TEST_DIR:-}" ] && rm -rf "${TEST_DIR}"
  return 0
}

# Number of hook entries referencing $HOOK across every matcher of a file.
hook_entry_count() {
  jq '[ (.hooks.PreToolUse // [])[] | (.hooks // [])[] | .command
        | select(contains("'"${HOOK}"'")) ] | length' "$1"
}

# Is $HOOK registered on a specific matcher?
has_matcher() {
  jq -e --arg m "$2" '
    any((.hooks.PreToolUse // [])[];
        .matcher == $m and
        any((.hooks // [])[]; (.command // "") | contains("'"${HOOK}"'")))
  ' "$1" >/dev/null
}

# ============================================================================
# Issue #65: a sync must leave BOTH settings paths registered
# ============================================================================

@test "#65 sync creates the missing ~/.config/claude/settings.json" {
  [ ! -f "${CONFIG_SETTINGS}" ]
  run "${SYNC}"
  [ "$status" -eq 0 ]
  [ -f "${CONFIG_SETTINGS}" ]
}

@test "#65 sync registers the hook in BOTH settings paths" {
  run "${SYNC}"
  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -gt 0 ]
  [ "$(hook_entry_count "${CONFIG_SETTINGS}")" -gt 0 ]
}

@test "#65 every registry matcher is present in BOTH settings paths" {
  run "${SYNC}"
  [ "$status" -eq 0 ]
  local m
  for m in Bash mcp__github__issue_write mcp__github__create_issue; do
    has_matcher "${CLAUDE_SETTINGS}" "$m"
    has_matcher "${CONFIG_SETTINGS}" "$m"
  done
}

@test "#65 the registered command is valid JSON pointing at the user hooks dir" {
  run "${SYNC}"
  [ "$status" -eq 0 ]
  jq -e . "${CONFIG_SETTINGS}" >/dev/null
  run jq -r '[ (.hooks.PreToolUse // [])[] | (.hooks // [])[] | .command ] | unique | join(" ")' "${CONFIG_SETTINGS}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"${HOME}/.claude/hooks/dist/${HOOK}"* ]]
}

@test "#65 a second sync is idempotent — no duplicate entries in either path" {
  run "${SYNC}"
  [ "$status" -eq 0 ]
  local first_claude first_config
  first_claude="$(hook_entry_count "${CLAUDE_SETTINGS}")"
  first_config="$(hook_entry_count "${CONFIG_SETTINGS}")"
  run "${SYNC}"
  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq "${first_claude}" ]
  [ "$(hook_entry_count "${CONFIG_SETTINGS}")" -eq "${first_config}" ]
}

@test "#65 sync works when BOTH settings paths already exist" {
  mkdir -p "$(dirname "${CONFIG_SETTINGS}")"
  printf '{}\n' > "${CONFIG_SETTINGS}"
  run "${SYNC}"
  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -gt 0 ]
  [ "$(hook_entry_count "${CONFIG_SETTINGS}")" -gt 0 ]
}

@test "#65 sync works when NEITHER settings path exists yet" {
  rm -f "${CLAUDE_SETTINGS}"
  run "${SYNC}"
  [ "$status" -eq 0 ]
  [ -f "${CLAUDE_SETTINGS}" ]
  [ -f "${CONFIG_SETTINGS}" ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -gt 0 ]
  [ "$(hook_entry_count "${CONFIG_SETTINGS}")" -gt 0 ]
}

# ============================================================================
# --ensure-both must not turn --dry-run into a writer, nor resurrect files on
# uninstall (both guarantees documented in install-hooks' header).
# ============================================================================

@test "#65 sync --dry-run creates no settings file" {
  run "${SYNC}" --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "${CONFIG_SETTINGS}" ]
}

@test "#65 sync --uninstall does not create the missing settings path" {
  run "${SYNC}" --uninstall
  [ "$status" -eq 0 ]
  [ ! -f "${CONFIG_SETTINGS}" ]
}

@test "#65 sync then sync --uninstall removes the registration from both paths" {
  run "${SYNC}"
  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CONFIG_SETTINGS}")" -gt 0 ]
  run "${SYNC}" --uninstall
  [ "$status" -eq 0 ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -eq 0 ]
  [ "$(hook_entry_count "${CONFIG_SETTINGS}")" -eq 0 ]
}

# ============================================================================
# Proof that the flag is what makes the difference — i.e. the fix had to be in
# sync's invocation, not in install-hooks' skip logic.
# ============================================================================

@test "#65 install-hooks WITHOUT --ensure-both still skips the missing path" {
  run "${INSTALL_HOOKS}"
  [ "$status" -eq 0 ]
  [ ! -f "${CONFIG_SETTINGS}" ]
  [ "$(hook_entry_count "${CLAUDE_SETTINGS}")" -gt 0 ]
}
