#!/usr/bin/env bats
#
# c-bpm-claude-md-hook-refs.bats — guards CLAUDE.md's "Enforcement: Hooks,
# Not Wrappers" section against doc/reality drift.
#
# Covers:
#   #66 — CLAUDE.md must not reference the phantom gh-issue-create-guard.sh;
#         the documented hook command must point at the real, shipped hook.
#   #67 — CLAUDE.md must cite the authoritative Claude Code hooks docs URL.
#
# Offline & deterministic: plain grep against tracked files. Run with:
#   bats tests/bash/c-bpm-claude-md-hook-refs.bats

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
DIST_HOOK="${REPO_ROOT}/dist/issue-write-gate.mjs"

setup() {
  [[ -f "${CLAUDE_MD}" ]] || skip "CLAUDE.md not found at ${CLAUDE_MD}"
}

@test "CLAUDE.md does not reference the phantom gh-issue-create-guard script (#66)" {
  run grep -n "gh-issue-create-guard" "${CLAUDE_MD}"
  [ "${status}" -ne 0 ]
}

@test "CLAUDE.md documents the exact real hook command (#66)" {
  # Assert the full documented command, not just the basename, so a regression
  # to a wrong path/executable is caught even if the basename lingers in prose.
  run grep -F "node ~/.claude/hooks/dist/issue-write-gate.mjs" "${CLAUDE_MD}"
  [ "${status}" -eq 0 ]
}

@test "the hook documented in CLAUDE.md exists in dist/ (#66)" {
  # Every hook command shown in CLAUDE.md must correspond to a shipped artifact.
  [ -f "${DIST_HOOK}" ]
}

@test "CLAUDE.md cites the two verified Claude Code hooks docs URLs (#67)" {
  # Lock in the exact URLs verified against; a permissive regex would pass even
  # if the citations were dropped or swapped.
  run grep -F "https://code.claude.com/docs/en/hooks-guide.md" "${CLAUDE_MD}"
  [ "${status}" -eq 0 ]
  run grep -F "https://code.claude.com/docs/en/hooks.md" "${CLAUDE_MD}"
  [ "${status}" -eq 0 ]
}
