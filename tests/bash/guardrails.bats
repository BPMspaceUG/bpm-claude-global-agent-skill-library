#!/usr/bin/env bats
#
# guardrails.bats — the pre-push hook and the live-test helper exist and work.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
LIVE="${REPO_ROOT}/tests/live/tmux-claude.sh"

@test "pre-push runs the bats suite and the mod type check" {
  local h="${REPO_ROOT}/.githooks/pre-push"
  [ -x "${h}" ]
  grep -qF './tests/run_tests.sh' "${h}"
  grep -qF './tests/typecheck-mods.sh' "${h}"
  [ -x "${REPO_ROOT}/tests/typecheck-mods.sh" ]
}

@test "tmux-claude.sh: start, send, wait for a pattern, time out, kill" {
  command -v tmux >/dev/null || skip "tmux missing"
  local s="bats-live-$$"
  "${LIVE}" start "${s}" 120 "${BATS_TEST_TMPDIR}" bash --norc
  "${LIVE}" send "${s}" 'echo DONE-$((40+2))' --enter
  "${LIVE}" wait "${s}" 'DONE-42' 10
  run "${LIVE}" wait "${s}" 'never-shown' 1
  "${LIVE}" kill "${s}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"timeout after 1s"* ]]
}
