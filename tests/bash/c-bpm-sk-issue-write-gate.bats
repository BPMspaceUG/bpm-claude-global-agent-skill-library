#!/usr/bin/env bats
#
# c-bpm-sk-issue-write-gate.bats — exercises my/hooks/issue-write-gate.mjs
# against the fixture set in my/hooks/__tests__/issue-write-gate.fixtures.json.
#
# Implements test plan from BPMspaceUG/bpm-claude-global-agent-skill-library#68.
# Run with: bats tests/bash/c-bpm-sk-issue-write-gate.bats

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
HOOK="${REPO_ROOT}/dist/issue-write-gate.mjs"
FIXTURES="${REPO_ROOT}/my/hooks/__tests__/issue-write-gate.fixtures.json"

# Mock milestone-resolution data: instead of calling `gh api`, the hook
# reads FIXTURE_MILESTONES (JSON object name→number) when this env var is set.
# Fixture data: new=1, planned=2, plan-approved=3, test-designed=4, resolved=13.
export FIXTURE_MILESTONES='{"new":1,"planned":2,"plan-approved":3,"test-designed":4,"test-design-approved":5,"implemented":6,"tested-success":7,"tested-failed":8,"test-approved":9,"reviewed":10,"review-approved":11,"investigating":12,"resolved":13}'

setup() {
  if [[ ! -f "${HOOK}" ]]; then
    skip "Hook not built yet at ${HOOK}; implementation pending (#68 Phase C)"
  fi
  if ! command -v node >/dev/null 2>&1; then
    skip "node not available"
  fi
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not available"
  fi
}

# Run a single fixture by id. Pipes the input JSON to the hook on stdin and
# captures stdout/exit. Returns 0 if observed decision matches expected.
run_fixture() {
  local fid="$1"
  local input expected_decision expected_reason
  input="$(jq -c ".fixtures[] | select(.id==${fid}) | .input" "${FIXTURES}")"
  expected_decision="$(jq -r ".fixtures[] | select(.id==${fid}) | .expected.decision" "${FIXTURES}")"
  expected_reason="$(jq -r ".fixtures[] | select(.id==${fid}) | .expected.reason_contains // \"\"" "${FIXTURES}")"

  [[ -n "${input}" ]] || { echo "fixture ${fid} not found"; return 1; }

  # Fixture 29 deliberately tests repo-resolution failure: unset FIXTURE_REPO,
  # set FIXTURE_REPO_RESOLVE=fail to force the fail-closed path.
  local extra_env=""
  if [[ "${fid}" == "29" ]]; then
    extra_env="FIXTURE_REPO_RESOLVE=fail"
  fi

  local out rc
  if [[ -n "${extra_env}" ]]; then
    out="$(echo "${input}" | env ${extra_env} node "${HOOK}" 2>&1)"
  else
    out="$(echo "${input}" | node "${HOOK}" 2>&1)"
  fi
  rc=$?

  local got_decision
  got_decision="$(echo "${out}" | jq -r '.permissionDecision // empty' 2>/dev/null || true)"

  # Hook contract: stdout is JSON {permissionDecision, permissionDecisionReason}.
  # Exit code 0 = ran successfully (decision in stdout). Non-zero = hook bug.
  if [[ "${rc}" -ne 0 ]]; then
    echo "fixture ${fid} HOOK ERROR (rc=${rc}): ${out}"
    return 1
  fi

  if [[ "${got_decision}" != "${expected_decision}" ]]; then
    echo "fixture ${fid} expected ${expected_decision}, got ${got_decision}. Output: ${out}"
    return 1
  fi

  if [[ -n "${expected_reason}" ]]; then
    local got_reason
    got_reason="$(echo "${out}" | jq -r '.permissionDecisionReason // empty')"
    if ! echo "${got_reason}" | grep -qiF "${expected_reason}"; then
      echo "fixture ${fid} reason missing '${expected_reason}'. Got: ${got_reason}"
      return 1
    fi
  fi
}

@test "fixture 1: gh issue create without milestone/label -> DENY" {
  run_fixture 1
}

@test "fixture 2: gh issue create --milestone only -> DENY (no type label)" {
  run_fixture 2
}

@test "fixture 3: --milestone new --label bug -> ALLOW" {
  run_fixture 3
}

@test "fixture 4: --label Bug (uppercase) -> DENY" {
  run_fixture 4
}

@test "fixture 5: --milestone nonexistent -> DENY (lifecycle)" {
  run_fixture 5
}

@test "fixture 6: MCP create with milestone number + enhancement -> ALLOW" {
  run_fixture 6
}

@test "fixture 7: MCP update (non-create) -> ALLOW (passthrough)" {
  run_fixture 7
}

@test "fixture 8: gh pr list (non-issue) -> ALLOW (passthrough)" {
  run_fixture 8
}

@test "fixture 9: short flags -m new -l bug -> ALLOW" {
  run_fixture 9
}

@test "fixture 10: equals form --milestone=new --label=bug -> ALLOW" {
  run_fixture 10
}

@test "fixture 11: both bug AND enhancement -> DENY (exactly-one)" {
  run_fixture 11
}

@test "fixture 12: comma-separated label bug,help-wanted -> ALLOW" {
  run_fixture 12
}

@test "fixture 13: non-type label only (help-wanted) -> DENY" {
  run_fixture 13
}

@test "fixture 14: echo \"gh issue create ...\" -> ALLOW (no false positive)" {
  run_fixture 14
}

@test "fixture 15: gh api -X POST repos/o/r/issues -> ALLOW" {
  run_fixture 15
}

@test "fixture 16: --milestone DONE -> DENY (human-only)" {
  run_fixture 16
}

@test "fixture 17: -XPOST no space -> ALLOW" {
  run_fixture 17
}

@test "fixture 18: --method=POST equals form -> ALLOW" {
  run_fixture 18
}

@test "fixture 19: gh api -X GET with -f -> ALLOW (read-only)" {
  run_fixture 19
}

@test "fixture 20: gh api -F (default-POST inferred) -> ALLOW" {
  run_fixture 20
}

@test "fixture 21: alternate MCP name create_issue -> ALLOW" {
  run_fixture 21
}

@test "fixture 22: MCP update_issue (non-create) -> ALLOW" {
  run_fixture 22
}

@test "fixture 23: --method=post lowercase -> ALLOW (case-insensitive)" {
  run_fixture 23
}

@test "fixture 24: command prefix stripped -> ALLOW" {
  run_fixture 24
}

@test "fixture 25: variable interpolation in --milestone -> DENY" {
  run_fixture 25
}

@test "fixture 26: MCP create with Bug uppercase -> DENY" {
  run_fixture 26
}

@test "fixture 27: MCP create with unknown milestone number -> DENY" {
  run_fixture 27
}

@test "fixture 28: Read tool (non-Bash, non-MCP-github) -> ALLOW (passthrough)" {
  run_fixture 28
}

@test "fixture 29: repo cannot be resolved -> DENY (fail-closed)" {
  run_fixture 29
}
