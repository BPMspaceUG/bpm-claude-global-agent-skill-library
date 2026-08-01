#!/usr/bin/env bats
#
# c-bpm-sk-plan-doc-gate.bats — exercises dist/plan-doc-gate.mjs against the
# fixture set in my/hooks/__tests__/plan-doc-gate.fixtures.json.
#
# Implements BPMspaceUG/bpm-claude-global-agent-skill-library#105 (runtime
# PreToolUse enforcement of #104), and carries the #133 fail-closed lesson.
# Run with: bats tests/bash/c-bpm-sk-plan-doc-gate.bats
#
# The suite is deliberately weighted toward NON-TARGET PASSTHROUGH. A gate on
# Write/Edit that over-blocks halts all repo work, so every allow-case here is
# a real file shape from this repository.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
HOOK="${REPO_ROOT}/dist/plan-doc-gate.mjs"
HOOK_TS="${REPO_ROOT}/my/hooks/plan-doc-gate.ts"
FIXTURES="${REPO_ROOT}/my/hooks/__tests__/plan-doc-gate.fixtures.json"

setup() {
  if [[ ! -f "${HOOK}" ]]; then
    skip "Hook not built yet at ${HOOK}"
  fi
  if ! command -v node >/dev/null 2>&1; then
    skip "node not available"
  fi
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not available"
  fi
  # #155 fixtures 50-57: materialize the spec-deliverable directory pair the
  # static fixture paths point at. rootA = SPEC.md + .git (sanctioned pair);
  # rootB = .git only (no SPEC.md); a planted SPEC.md under .claude/plans/
  # must NOT sanction anything.
  local e2e=/tmp/plan-doc-gate-e2e
  mkdir -p "${e2e}/rootA/sub" "${e2e}/rootA/.git" "${e2e}/rootB/.git" "${e2e}/.claude/plans"
  touch "${e2e}/rootA/SPEC.md" "${e2e}/.claude/plans/SPEC.md"
  rm -f "${e2e}/rootB/SPEC.md"
}

# Run a single fixture by id. Pipes the input JSON to the hook on stdin and
# captures stdout/exit. Returns 0 if observed decision matches expected.
run_fixture() {
  local fid="$1"
  local input expected_decision expected_reason extra_env
  input="$(jq -c ".fixtures[] | select(.id==${fid}) | .input" "${FIXTURES}")"
  expected_decision="$(jq -r ".fixtures[] | select(.id==${fid}) | .expected.decision" "${FIXTURES}")"
  expected_reason="$(jq -r ".fixtures[] | select(.id==${fid}) | .expected.reason_contains // \"\"" "${FIXTURES}")"
  extra_env="$(jq -r ".fixtures[] | select(.id==${fid}) | (.env // []) | join(\" \")" "${FIXTURES}")"

  [[ -n "${input}" ]] || { echo "fixture ${fid} not found"; return 1; }

  local out rc
  set +e
  if [[ -n "${extra_env}" ]]; then
    out="$(echo "${input}" | env ${extra_env} node "${HOOK}" 2>&1)"
  else
    out="$(echo "${input}" | node "${HOOK}" 2>&1)"
  fi
  rc=$?
  set -e

  # Hook contract: exit code 0 = ran successfully (decision in stdout).
  # Non-zero = hook bug. #133: a non-zero exit with empty stdout fails OPEN.
  if [[ "${rc}" -ne 0 ]]; then
    echo "fixture ${fid} HOOK ERROR (rc=${rc}): ${out}"
    return 1
  fi

  # #99: the NESTED hookSpecificOutput shape is authoritative — it is what
  # current Claude Code builds read. If it is missing the gate fails OPEN.
  local event got_decision got_reason flat_decision flat_reason
  event="$(echo "${out}" | jq -r '.hookSpecificOutput.hookEventName // empty' 2>/dev/null || true)"
  got_decision="$(echo "${out}" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null || true)"
  got_reason="$(echo "${out}" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null || true)"

  if [[ "${event}" != "PreToolUse" ]]; then
    echo "fixture ${fid} missing hookSpecificOutput.hookEventName=PreToolUse. Output: ${out}"
    return 1
  fi

  if [[ "${got_decision}" != "${expected_decision}" ]]; then
    echo "fixture ${fid} expected ${expected_decision}, got ${got_decision}. Output: ${out}"
    return 1
  fi

  # #99: legacy flat mirror must be present and identical, so a build reading
  # either shape gets the same decision.
  flat_decision="$(echo "${out}" | jq -r '.permissionDecision // empty' 2>/dev/null || true)"
  flat_reason="$(echo "${out}" | jq -r '.permissionDecisionReason // empty' 2>/dev/null || true)"
  if [[ "${flat_decision}" != "${got_decision}" || "${flat_reason}" != "${got_reason}" ]]; then
    echo "fixture ${fid} flat mirror inconsistent with nested shape. Output: ${out}"
    return 1
  fi

  if [[ -n "${expected_reason}" ]]; then
    if ! printf '%s\n' "${got_reason}" | grep -qiF -- "${expected_reason}"; then
      echo "fixture ${fid} reason missing '${expected_reason}'. Got: ${got_reason}"
      return 1
    fi
  fi
}

# ── Positive enforcement: the side-car class named by #104 ────────────────

@test "fixture 1: Write into ~/.claude/plans/ -> DENY" {
  run_fixture 1
}

@test "fixture 2: .claude/plans/notes.txt -> DENY (extension-independent)" {
  run_fixture 2
}

@test "fixture 3: repo-root plan.md -> DENY" {
  run_fixture 3
}

@test "fixture 4: ISSUE_105_PLAN.md -> DENY" {
  run_fixture 4
}

@test "fixture 5: scratchpad prompt.md -> DENY" {
  run_fixture 5
}

@test "fixture 6: implementation-plan.md -> DENY" {
  run_fixture 6
}

@test "fixture 7: issue-95-notes.md -> DENY" {
  run_fixture 7
}

@test "fixture 8: Edit of an existing scratchpad.md -> DENY" {
  run_fixture 8
}

@test "fixture 9: MultiEdit of plans.md -> DENY" {
  run_fixture 9
}

# ── #95-class docs regression ─────────────────────────────────────────────
#
# #95 adds agent.md alongside CLAUDE.md and README.md. If this gate blocked
# those, it would block the very issue it ships beside. These four are the
# explicit regression Codex required.

@test "#95 regression: CLAUDE.md -> ALLOW" {
  run_fixture 20
}

@test "#95 regression: agent.md -> ALLOW" {
  run_fixture 21
}

@test "#95 regression: README.md -> ALLOW" {
  run_fixture 22
}

@test "#95 regression: Edit CLAUDE.md in place -> ALLOW" {
  run_fixture 23
}

# ── Non-target passthrough: ordinary repo work ────────────────────────────

@test "passthrough: SHARED_TASK_NOTES.md -> ALLOW" {
  run_fixture 24
}

@test "passthrough: a skill SKILL.md -> ALLOW" {
  run_fixture 25
}

@test "passthrough: templates/ISSUE_TEMPLATE.md -> ALLOW (no digits, allowlisted dir)" {
  run_fixture 26
}

@test "passthrough: db_migration_playbook.md -> ALLOW (PLAN_SUFFIX anchored)" {
  run_fixture 27
}

@test "passthrough: my/hooks/plan-doc-gate.ts -> ALLOW (source, not a doc)" {
  run_fixture 28
}

@test "passthrough: dist/plan-doc-gate.mjs -> ALLOW (build artifact)" {
  run_fixture 29
}

@test "passthrough: install-hooks, extensionless script -> ALLOW" {
  run_fixture 32
}

@test "passthrough: a .bats test file -> ALLOW" {
  run_fixture 33
}

@test "passthrough: a .json fixture file -> ALLOW" {
  run_fixture 34
}

@test "passthrough: scripts/plan.py -> ALLOW (side-car stem, non-doc extension)" {
  run_fixture 35
}

@test "passthrough: tests/bash/fixtures/plan.md -> ALLOW (allowlisted segment)" {
  run_fixture 36
}

@test "passthrough: NotebookEdit on a .ipynb -> ALLOW" {
  run_fixture 40
}

# ── #155 spec-deliverable exception ───────────────────────────────────────
#
# Exactly one sanctioned allow inside the deny set: exact-name PLAN.md whose
# directory also holds SPEC.md and a .git entry (repo root). Narrowness is
# proven by keeping every other side-car denied WITH SPEC.md present.

@test "#155 fixture 50: root PLAN.md with SPEC.md + .git -> ALLOW (reason names SPEC.md)" {
  run_fixture 50
}

@test "#155 fixture 51: root PLAN.md without SPEC.md -> DENY" {
  run_fixture 51
}

@test "#155 fixture 52: nested PLAN.md, SPEC.md only above -> DENY" {
  run_fixture 52
}

@test "#155 fixture 53: ISSUE_12_PLAN.md denied despite SPEC.md" {
  run_fixture 53
}

@test "#155 fixture 54: implementation-plan.md denied despite SPEC.md" {
  run_fixture 54
}

@test "#155 fixture 55: .claude/plans/PLAN.md denied despite planted SPEC.md" {
  run_fixture 55
}

@test "#155 fixture 56: lowercase plan.md denied despite SPEC.md (exact-name rule)" {
  run_fixture 56
}

@test "#155 fixture 57: Edit tool on sanctioned PLAN.md -> ALLOW" {
  run_fixture 57
}

@test "#155 documentation: ts and dist rule text both name the SPEC.md carve-out" {
  grep -qF 'SPEC.md' "${HOOK_TS}"
  grep -qF 'SPEC.md' "${HOOK}"
}

# ── Content blindness ─────────────────────────────────────────────────────
#
# Codex's bar: "must NOT block a file merely because its contents 'look like'
# a plan". These two ship plan-shaped bodies through allowed paths.

@test "content blindness: README.md whose body is an implementation plan -> ALLOW" {
  run_fixture 30
}

@test "content blindness: runbook containing 'scratchpad'/'ISSUE_105_PLAN' prose -> ALLOW" {
  run_fixture 31
}

@test "content blindness: hook never reads tool_input.content for any decision" {
  # Same allowed path, with and without a plan-shaped body: identical verdict.
  local with_content without_content
  with_content="$(printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"/r/README.md","content":"# Plan\n- [ ] ISSUE_1_PLAN scratchpad prompt"}}' \
    | node "${HOOK}" | jq -r '.hookSpecificOutput.permissionDecision')"
  without_content="$(printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"/r/README.md"}}' \
    | node "${HOOK}" | jq -r '.hookSpecificOutput.permissionDecision')"
  [[ "${with_content}" == "allow" ]] || { echo "content-bearing write was ${with_content}"; return 1; }
  [[ "${with_content}" == "${without_content}" ]]
}

# ── Scope ─────────────────────────────────────────────────────────────────

@test "scope: Bash is not gated by this hook -> ALLOW" {
  run_fixture 37
}

@test "scope: Read is not gated -> ALLOW" {
  run_fixture 38
}

@test "scope: Write with no file_path -> ALLOW" {
  run_fixture 39
}

# ── Fail-closed on internal error (#133) ──────────────────────────────────
#
# The sibling hook exits 1 with EMPTY stdout on an unhandled exception, so no
# decision reaches the harness and it fails OPEN. This gate must instead emit a
# valid `deny` and still exit 0. PLAN_DOC_GATE_FORCE_ERROR=1 forces the throw.

@test "fixture 41: forced internal error -> DENY (fail-closed)" {
  run_fixture 41
}

@test "#133: forced internal error exits 0 with a parseable deny on stdout" {
  local out rc
  set +e
  out="$(printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"/r/README.md"}}' \
    | PLAN_DOC_GATE_FORCE_ERROR=1 node "${HOOK}" 2>/dev/null)"
  rc=$?
  set -e
  [[ "${rc}" -eq 0 ]] || { echo "exit ${rc}, expected 0 (non-zero + empty stdout = fail OPEN)"; return 1; }
  [[ -n "${out}" ]] || { echo "empty stdout on internal error — fails OPEN"; return 1; }
  echo "${out}" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null
  echo "${out}" | jq -e '.permissionDecision == "deny"' >/dev/null
}

@test "#133: an unparseable stdin payload is not treated as an internal error" {
  # No path to classify, so denying would halt every write. Documented in
  # _known_gap / the hook header: this is allow-by-design, not fail-open drift.
  local out
  out="$(printf 'not json at all' | node "${HOOK}")"
  echo "${out}" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' >/dev/null
}

# ── ts <-> dist parity ────────────────────────────────────────────────────
#
# dist/plan-doc-gate.mjs is what Claude Code executes; the .ts is the declared
# source of truth. This repo has NO build step, so nothing regenerates the
# artifact — the two are hand-maintained and can silently diverge.
#
# THIS IS A TRIPWIRE, NOT PROOF OF EQUIVALENCE: the declaration check compares
# NAMES ONLY, and the checksum pin only catches ACCIDENTAL drift (edit both and
# re-pin both, and it passes regardless of behaviour). Same limitation as the
# sibling suite, stated for the same reason.

@test "ts/dist parity: identical top-level declarations" {
  [[ -f "${HOOK_TS}" ]] || { echo "missing ${HOOK_TS}"; return 1; }
  local ts_decl dist_decl
  ts_decl="$(grep -oE '^(function|const|let) [A-Za-z0-9_]+' "${HOOK_TS}" | sort)"
  dist_decl="$(grep -oE '^(function|const|let) [A-Za-z0-9_]+' "${HOOK}" | sort)"
  if [[ "${ts_decl}" != "${dist_decl}" ]]; then
    echo "ts <-> dist declaration drift:"
    diff <(echo "${ts_decl}") <(echo "${dist_decl}") || true
    return 1
  fi
}

@test "ts/dist parity: recorded checksums match both files" {
  command -v sha256sum >/dev/null 2>&1 || skip "sha256sum not available"
  local want_ts want_dist got_ts got_dist
  want_ts="$(jq -r '._parity["my/hooks/plan-doc-gate.ts"]' "${FIXTURES}")"
  want_dist="$(jq -r '._parity["dist/plan-doc-gate.mjs"]' "${FIXTURES}")"
  got_ts="$(sha256sum "${HOOK_TS}" | cut -d' ' -f1)"
  got_dist="$(sha256sum "${HOOK}" | cut -d' ' -f1)"
  if [[ "${got_ts}" != "${want_ts}" || "${got_dist}" != "${want_dist}" ]]; then
    echo "plan-doc-gate source/artifact changed without updating the parity pin."
    echo "  ts:   want ${want_ts} got ${got_ts}"
    echo "  dist: want ${want_dist} got ${got_dist}"
    echo "Mirror the change into BOTH files, then update ._parity in ${FIXTURES}."
    return 1
  fi
}

# ── Registration ──────────────────────────────────────────────────────────

@test "install-hooks registers plan-doc-gate on the write tools" {
  local reg
  reg="$(grep -E '^\s*"plan-doc-gate\|' "${REPO_ROOT}/install-hooks")"
  [[ -n "${reg}" ]] || { echo "no HOOK_REGISTRY entry for plan-doc-gate"; return 1; }
  [[ "${reg}" == *"Write"* && "${reg}" == *"Edit"* && "${reg}" == *"NotebookEdit"* ]]
}
