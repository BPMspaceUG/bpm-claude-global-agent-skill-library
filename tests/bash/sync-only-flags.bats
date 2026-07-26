#!/usr/bin/env bats
#
# sync-only-flags.bats — regression tests for Issue #77.
#
# `MY_DIRS` was assigned only in the else branch of the DIRS selection in
# `sync`, but read unconditionally by the my/ sync loop. Under `set -euo
# pipefail` every --only-* invocation therefore died with
# "MY_DIRS: unbound variable" before syncing anything.
#
# Every test drives the REAL sync script — nothing greps the source.
#
# Safety:
#   - $HOME is redirected to a temp dir for every test.
#   - sync is copied into a temp sandbox "extracted tarball" together with
#     lib.sh and a small fake payload, so the working tree is never the source
#     and never the target.
#   - install-hooks is deliberately NOT copied into the sandbox: sync only runs
#     it when it is executable at SCRIPT_DIR, so these tests never touch any
#     settings.json. Both-settings behaviour is covered by
#     install-hooks-both-settings.bats.

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

setup() {
  TEST_DIR="$(mktemp -d)"

  SANDBOX="${TEST_DIR}/extracted"
  mkdir -p "${SANDBOX}"
  cp "${REPO_ROOT}/sync" "${SANDBOX}/sync"
  cp "${REPO_ROOT}/lib.sh" "${SANDBOX}/lib.sh"
  chmod +x "${SANDBOX}/sync"
  SYNC="${SANDBOX}/sync"

  # Fake payload: one plain file per standard dir ...
  local d
  for d in agents skills runbooks templates; do
    mkdir -p "${SANDBOX}/${d}"
    printf 'payload %s\n' "${d}" > "${SANDBOX}/${d}/upstream-${d}.md"
  done

  # ... and one c-bpm item per my/ category (skills are directories).
  mkdir -p "${SANDBOX}/my/skills/c-bpm-sk-probe"
  printf '# probe skill\n' > "${SANDBOX}/my/skills/c-bpm-sk-probe/SKILL.md"
  mkdir -p "${SANDBOX}/my/agents" "${SANDBOX}/my/commands" "${SANDBOX}/my/runbooks"
  printf '# probe agent\n'   > "${SANDBOX}/my/agents/c-bpm-ag-probe.md"
  printf '# probe command\n' > "${SANDBOX}/my/commands/c-bpm-cm-probe.md"
  printf '# probe runbook\n' > "${SANDBOX}/my/runbooks/c-bpm-rb-probe.md"

  export HOME="${TEST_DIR}/home"
  mkdir -p "${HOME}/.claude"
  printf '{}\n' > "${HOME}/.claude/settings.json"
  TARGET="${HOME}/.claude"
}

teardown() {
  [ -n "${TEST_DIR:-}" ] && rm -rf "${TEST_DIR}"
  return 0
}

# ============================================================================
# Issue #77: every --only-* flag must run instead of aborting under set -u
# ============================================================================

@test "#77 sync --only-skills exits 0 and does not report an unbound variable" {
  run "${SYNC}" --only-skills
  [ "$status" -eq 0 ]
  ! grep -q "unbound variable" <<< "$output"
  [ -f "${TARGET}/skills/upstream-skills.md" ]
}

@test "#77 sync --only-agents exits 0 and does not report an unbound variable" {
  run "${SYNC}" --only-agents
  [ "$status" -eq 0 ]
  ! grep -q "unbound variable" <<< "$output"
  [ -f "${TARGET}/agents/upstream-agents.md" ]
}

@test "#77 sync --only-runbooks exits 0 and does not report an unbound variable" {
  run "${SYNC}" --only-runbooks
  [ "$status" -eq 0 ]
  ! grep -q "unbound variable" <<< "$output"
  [ -f "${TARGET}/runbooks/upstream-runbooks.md" ]
}

@test "#77 sync --only-templates exits 0 (selects no my/ category at all)" {
  run "${SYNC}" --only-templates
  [ "$status" -eq 0 ]
  ! grep -q "unbound variable" <<< "$output"
  [ -f "${TARGET}/templates/upstream-templates.md" ]
  # No my/ category maps to templates, so nothing c-bpm-prefixed is installed.
  [ ! -d "${TARGET}/skills/c-bpm-sk-probe" ]
  [ ! -f "${TARGET}/commands/c-bpm-cm-probe.md" ]
}

@test "#77 sync --only-skills --only-agents (combined) exits 0" {
  run "${SYNC}" --only-skills --only-agents
  [ "$status" -eq 0 ]
  ! grep -q "unbound variable" <<< "$output"
  [ -f "${TARGET}/skills/upstream-skills.md" ]
  [ -f "${TARGET}/agents/upstream-agents.md" ]
  [ ! -f "${TARGET}/runbooks/upstream-runbooks.md" ]
}

@test "#77 sync --only-skills --dry-run exits 0 and writes nothing" {
  run "${SYNC}" --only-skills --dry-run
  [ "$status" -eq 0 ]
  ! grep -q "unbound variable" <<< "$output"
  [ ! -f "${TARGET}/skills/upstream-skills.md" ]
  [ ! -d "${TARGET}/skills/c-bpm-sk-probe" ]
}

# ============================================================================
# --only-* narrows the my/ categories the same way it narrows the plain dirs
# ============================================================================

@test "#77 sync --only-skills installs my/skills but not my/commands" {
  run "${SYNC}" --only-skills
  [ "$status" -eq 0 ]
  [ -f "${TARGET}/skills/c-bpm-sk-probe/SKILL.md" ]
  [ ! -f "${TARGET}/commands/c-bpm-cm-probe.md" ]
  [ ! -f "${TARGET}/agents/c-bpm-ag-probe.md" ]
}

@test "#77 sync --only-agents installs my/agents but not my/skills" {
  run "${SYNC}" --only-agents
  [ "$status" -eq 0 ]
  [ -f "${TARGET}/agents/c-bpm-ag-probe.md" ]
  [ ! -d "${TARGET}/skills/c-bpm-sk-probe" ]
}

# ============================================================================
# The default (no --only-*) path must keep syncing all four my/ categories
# ============================================================================

@test "#77 sync without --only-* still installs every my/ category" {
  run "${SYNC}"
  [ "$status" -eq 0 ]
  [ -f "${TARGET}/skills/c-bpm-sk-probe/SKILL.md" ]
  [ -f "${TARGET}/agents/c-bpm-ag-probe.md" ]
  [ -f "${TARGET}/commands/c-bpm-cm-probe.md" ]
  [ -f "${TARGET}/runbooks/c-bpm-rb-probe.md" ]
}

@test "#77 sync --only-skills is idempotent (second run also exits 0)" {
  run "${SYNC}" --only-skills
  [ "$status" -eq 0 ]
  run "${SYNC}" --only-skills
  [ "$status" -eq 0 ]
  ! grep -q "unbound variable" <<< "$output"
}
