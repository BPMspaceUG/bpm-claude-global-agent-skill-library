#!/usr/bin/env bats
#
# c-bpm-sk-issue-write-gate.bats — exercises dist/issue-write-gate.mjs
# against the fixture set in my/hooks/__tests__/issue-write-gate.fixtures.json.
#
# Implements test plan from BPMspaceUG/bpm-claude-global-agent-skill-library#68,
# plus #69 #70 #71 #72 #73 #74 #99 #100.
# Run with: bats tests/bash/c-bpm-sk-issue-write-gate.bats

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
HOOK="${REPO_ROOT}/dist/issue-write-gate.mjs"
HOOK_TS="${REPO_ROOT}/my/hooks/issue-write-gate.ts"
FIXTURES="${REPO_ROOT}/my/hooks/__tests__/issue-write-gate.fixtures.json"

# Mock milestone-resolution data: instead of calling `gh api`, the hook
# reads FIXTURE_MILESTONES (JSON object name→number) when this env var is set.
# Fixture data: new=1, planned=2, plan-approved=3, test-designed=4, resolved=13.
export FIXTURE_MILESTONES='{"new":1,"planned":2,"plan-approved":3,"test-designed":4,"test-design-approved":5,"implemented":6,"tested-success":7,"tested-failed":8,"test-approved":9,"reviewed":10,"review-approved":11,"investigating":12,"resolved":13}'

# #100: fixture cwd /tmp/repo is not a git checkout, so resolveRepo() would
# return null and every milestone-validating case would deny with "cannot
# resolve owner/repo". Mock the repo the same way milestones are mocked.
# Fixtures that must exercise the fail-closed path declare
# "env": ["FIXTURE_REPO_RESOLVE=fail"], which resolveRepo() checks first.
export FIXTURE_REPO='o/r'

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
  local input expected_decision expected_reason extra_env
  input="$(jq -c ".fixtures[] | select(.id==${fid}) | .input" "${FIXTURES}")"
  expected_decision="$(jq -r ".fixtures[] | select(.id==${fid}) | .expected.decision" "${FIXTURES}")"
  expected_reason="$(jq -r ".fixtures[] | select(.id==${fid}) | .expected.reason_contains // \"\"" "${FIXTURES}")"
  # Per-fixture env overrides (e.g. FIXTURE_REPO_RESOLVE=fail for the
  # fail-closed repo-resolution cases).
  extra_env="$(jq -r ".fixtures[] | select(.id==${fid}) | (.env // []) | join(\" \")" "${FIXTURES}")"

  [[ -n "${input}" ]] || { echo "fixture ${fid} not found"; return 1; }

  local out rc
  if [[ -n "${extra_env}" ]]; then
    out="$(echo "${input}" | env ${extra_env} node "${HOOK}" 2>&1)"
  else
    out="$(echo "${input}" | node "${HOOK}" 2>&1)"
  fi
  rc=$?

  # Hook contract: exit code 0 = ran successfully (decision in stdout).
  # Non-zero = hook bug.
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

  # #99: legacy flat mirror must be present and identical for one transition
  # release, so a build reading either shape gets the same decision.
  flat_decision="$(echo "${out}" | jq -r '.permissionDecision // empty' 2>/dev/null || true)"
  flat_reason="$(echo "${out}" | jq -r '.permissionDecisionReason // empty' 2>/dev/null || true)"
  if [[ "${flat_decision}" != "${got_decision}" || "${flat_reason}" != "${got_reason}" ]]; then
    echo "fixture ${fid} flat mirror inconsistent with nested shape. Output: ${out}"
    return 1
  fi

  if [[ -n "${expected_reason}" ]]; then
    # `--` and printf: expected_reason may start with a dash (e.g. "--input").
    if ! printf '%s\n' "${got_reason}" | grep -qiF -- "${expected_reason}"; then
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

@test "fixture 30 (#70): /usr/bin/gh compliant -> ALLOW (basename detection)" {
  run_fixture 30
}

@test "fixture 31 (#70): /usr/bin/gh without milestone -> DENY (bypass closed)" {
  run_fixture 31
}

@test "fixture 32 (#69): non-git cwd + --repo o/r -> ALLOW (flag overrides git)" {
  run_fixture 32
}

@test "fixture 33 (#73): -m=new -l=bug -> ALLOW (short-flag-equals)" {
  run_fixture 33
}

@test "fixture 34 (#72): gh api --input body.json -> DENY (opaque, fail-closed)" {
  run_fixture 34
}

@test "fixture 35 (#72): gh api --raw-field create without milestone -> DENY" {
  run_fixture 35
}

@test "fixture 36 (#72): gh api --field create compliant -> ALLOW" {
  run_fixture 36
}

@test "fixture 37 (#71): sudo/timeout/env wrapper chain -> DENY" {
  run_fixture 37
}

@test "fixture 38 (#71): nohup/stdbuf wrapper chain compliant -> ALLOW" {
  run_fixture 38
}

@test "fixture 39 (#71): eval payload -> DENY (recursive unwrap)" {
  run_fixture 39
}

@test "fixture 40 (#71): bash -lc payload compliant -> ALLOW" {
  run_fixture 40
}

@test "fixture 41 (#71): nesting beyond MAX_DEPTH -> DENY (depth guard)" {
  run_fixture 41
}

@test "fixture 42 (#71): inner payload tokenise failure -> DENY (fail-closed)" {
  run_fixture 42
}

@test "fixture 43 (#74): curl POST to issues API without milestone -> DENY" {
  run_fixture 43
}

@test "fixture 44 (#74): python requests.post without milestone -> DENY" {
  run_fixture 44
}

@test "fixture 45 (#74): curl POST with milestone + type label -> ALLOW" {
  run_fixture 45
}

@test "fixture 46 (#71): gh issue create after && -> DENY (segment scan)" {
  run_fixture 46
}

@test "fixture 47 (#72): gh api graphql createIssue mutation -> DENY" {
  run_fixture 47
}

# Fixtures 48-52 (#71) are REGRESSION tests for a live bypass found by Codex
# verification, not hypotheticals. Before the decideSegment() fix, 48/49/50 all
# returned ALLOW against the real hook: the shell runner sat behind a wrapper so
# head-only runner detection never unwrapped it, and the fallback `gh` scan
# could not see `gh` inside the quoted payload. 51 guards the opposite failure
# (over-blocking a compliant wrapped command); 52 proves the fail-closed
# tokenisation path is now reachable behind a wrapper rather than bypassed.

@test "fixture 48 (#71): sudo bash -lc \"gh issue create\" -> DENY (was ALLOW)" {
  run_fixture 48
}

@test "fixture 49 (#71): env bash -lc \"gh issue create\" -> DENY (was ALLOW)" {
  run_fixture 49
}

@test "fixture 50 (#71): sudo env bash -lc double wrapper -> DENY (was ALLOW)" {
  run_fixture 50
}

@test "fixture 51 (#71): sudo bash -lc compliant -> ALLOW (no over-block)" {
  run_fixture 51
}

@test "fixture 52 (#71): wrapped unparsable payload -> DENY (fail-closed reachable)" {
  run_fixture 52
}

# Fixtures 53-59 (#133) are REGRESSION tests for a second live bypass found by
# Codex verification. SHELL_RUNNERS was an ALLOWLIST deciding what to unwrap, so
# every shell name not in it failed open: 53 (rbash), 54 (/opt/bin/mysh) and 59
# (busybox ash) all returned ALLOW against the real hook. The unwrap now
# triggers on SHAPE — a `-c`/`-lc`/`-ic` flag carrying a payload — regardless of
# the head's name.
#
# 55 is the one required case that was ALREADY green before the fix (the `sh`
# applet is in SHELL_RUNNERS and the scan finds it mid-segment); it is pinned as
# a no-regression guard, not as proof of the fix — 59 is the same shape with
# that allowlist coincidence removed.
#
# 56-58 are the over-block controls: shape-based unwrap must not turn a quoted
# MENTION into a denial.

@test "fixture 53 (#133): rbash -lc \"gh issue create\" -> DENY (was ALLOW)" {
  run_fixture 53
}

@test "fixture 54 (#133): /opt/bin/mysh -c path-qualified unknown shell -> DENY (was ALLOW)" {
  run_fixture 54
}

@test "fixture 55 (#133): busybox sh -c -> DENY (already green; no-regression pin)" {
  run_fixture 55
}

@test "fixture 56 (#133): unknown shell wrapping compliant create -> ALLOW (no over-block)" {
  run_fixture 56
}

@test "fixture 57 (#133): echo \"gh issue create\" mention -> ALLOW (no over-block)" {
  run_fixture 57
}

@test "fixture 58 (#133): grep pattern \"gh issue create\" -> ALLOW (no over-block)" {
  run_fixture 58
}

@test "fixture 59 (#133): busybox ash -c \"gh issue create\" -> DENY (was ALLOW)" {
  run_fixture 59
}

# Fixtures 60-63 (#136) cover the FALSE POSITIVE the #133 shape-based unwrap
# introduced, found by Codex verification. `-c` was treated as a shell payload
# flag whatever the head was, so `grep -c "gh issue create" notes.txt` — grep's
# COUNT flag — had its PATTERN re-gated and DENIED: the gate blocked auditing
# this repo for that pattern. 60 and 62 both returned DENY against the real hook
# before the fix; 61 was ALLOW only because its apostrophe broke tokenisation.
#
# 62 is deliberately the TERMINAL-payload shape (no trailing operand), which a
# position-only heuristic could not have fixed. 63 is the bypass guard: the
# NON_SHELL_C_FLAG exception is scoped to the word that OWNS the flag, so a
# trailing `grep` operand cannot switch the unwrap off and reopen #133.

@test "fixture 60 (#136): grep -c \"gh issue create\" notes.txt -> ALLOW (was DENY)" {
  run_fixture 60
}

@test "fixture 61 (#136): grep -c \"it's\" file.txt -> ALLOW (no over-block)" {
  run_fixture 61
}

@test "fixture 62 (#136): sort -c terminal payload with create text -> ALLOW (was DENY)" {
  run_fixture 62
}

@test "fixture 63 (#136): mysh -c payload + trailing \"grep\" operand -> DENY (owner-scoped)" {
  run_fixture 63
}

# ── ts <-> dist parity ────────────────────────────────────────────────────
#
# dist/issue-write-gate.mjs is what Claude Code executes; the .ts is the
# declared source of truth. This repo has NO build step (no package.json, no
# tsc, no bundler), so nothing regenerates the artifact — the two files are
# hand-maintained and can silently diverge. Two guards:
#   1. declaration parity: same top-level function/const/let names in both;
#   2. checksum pin recorded in the fixtures file, so editing one file without
#      the other fails the suite until both are re-checksummed.
#
# THIS IS A TRIPWIRE, NOT PROOF OF EQUIVALENCE. Read that literally before
# relying on it:
#   - the declaration check compares NAMES ONLY. It says nothing about
#     semantics: a changed regex, a flipped boolean or an inverted branch
#     inside a function body passes it unchanged.
#   - the checksum pin only catches ACCIDENTAL drift, i.e. editing one file and
#     forgetting the other. Anyone who edits both files and re-pins both hashes
#     passes it, whether or not the two are behaviourally identical.
#   - only the .mjs is ever executed — by this suite and by Claude Code — so a
#     divergent .ts is silently dead documentation that a future editor will
#     nonetheless trust.
# A real build step (or deleting the .ts and making the .mjs the sole source)
# is the only thing that would make these two provably equivalent.

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
  want_ts="$(jq -r '._parity["my/hooks/issue-write-gate.ts"]' "${FIXTURES}")"
  want_dist="$(jq -r '._parity["dist/issue-write-gate.mjs"]' "${FIXTURES}")"
  got_ts="$(sha256sum "${HOOK_TS}" | cut -d' ' -f1)"
  got_dist="$(sha256sum "${HOOK}" | cut -d' ' -f1)"
  if [[ "${got_ts}" != "${want_ts}" || "${got_dist}" != "${want_dist}" ]]; then
    echo "issue-write-gate source/artifact changed without updating the parity pin."
    echo "  ts:   want ${want_ts} got ${got_ts}"
    echo "  dist: want ${want_dist} got ${got_dist}"
    echo "Mirror the change into BOTH files, then update ._parity in ${FIXTURES}."
    return 1
  fi
}
