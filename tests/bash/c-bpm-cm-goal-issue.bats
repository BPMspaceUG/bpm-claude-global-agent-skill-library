#!/usr/bin/env bats
#
# c-bpm-cm-goal-issue.bats - Content guards for the GOAL ISSUE command (Issue #112)
# Run with: bats tests/bash/c-bpm-cm-goal-issue.bats
#
# Scope: static content guards on my/commands/c-bpm-cm-goal-issue.md only.
# The 14 tests below implement the Codex-approved "Implementation Plan v2"
# coverage list from Issue #112. Two of them lock in the policy precedences
# that Codex required (no `model:` frontmatter key; SUMMARY artifact only
# allowed together with its explicit precedence statement).
#
# NOTE: every grep is scoped to ${CMD} (a path under my/), never to a
# directory tree, so the guard patterns in this file cannot match themselves.
#
# Byte-identity of the issue-communication block is covered by
# issue-comms-anchor.bats; codex invocation hygiene by
# c-bpm-sk-codex-invocation-hygiene.bats. Not duplicated here.

set -u

setup() {
  REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  CMD="${REPO_ROOT}/my/commands/c-bpm-cm-goal-issue.md"
}

# Extract the first `---` .. `---` YAML frontmatter block (exclusive of fences).
frontmatter() {
  awk '
    NR == 1 && $0 == "---" { inblock = 1; next }
    inblock && $0 == "---"  { exit }
    inblock                 { print }
  ' "$1"
}

# The SUMMARY section: the line naming the report file plus its surrounding
# context. Tests 12 and 13 are coupled through this window, so the precedence
# statement must live WITH the artifact, not somewhere else in the file.
SUMMARY_FILE_RE='SUMMARY-(<YYYYMMDD>-<HHMM>|%Y%m%d-%H%M|\$\(date[^)]*\))\.md'

summary_window() {
  grep -E -B2 -A15 "${SUMMARY_FILE_RE}" "$1" || true
}

# Clean guard so a missing command file fails as an assertion, not a script error.
require_cmd() {
  if [[ ! -f "${CMD}" ]]; then
    printf 'Command file not found: my/commands/c-bpm-cm-goal-issue.md\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 1 — the command file exists
# ------------------------------------------------------------------

@test "1: my/commands/c-bpm-cm-goal-issue.md exists" {
  require_cmd
}

# ------------------------------------------------------------------
# 2 — frontmatter carries name + a trigger-rich description
# ------------------------------------------------------------------

@test "2: frontmatter declares name and a trigger-rich description" {
  require_cmd
  local fm
  fm="$(frontmatter "${CMD}")"

  if [[ -z "${fm}" ]]; then
    printf 'No YAML frontmatter block found at the top of the command file.\n' >&2
    return 1
  fi
  if ! printf '%s\n' "${fm}" | grep -qE '^name:[[:space:]]*c-bpm-cm-goal-issue[[:space:]]*$'; then
    printf 'Frontmatter must declare: name: c-bpm-cm-goal-issue\n' >&2
    return 1
  fi
  if ! printf '%s\n' "${fm}" | grep -qE '^description:[[:space:]]*\S'; then
    printf 'Frontmatter must declare a non-empty description.\n' >&2
    return 1
  fi
  if ! printf '%s\n' "${fm}" | grep -qiE '^description:.*(overnight|unattended|goal issue|nachtlauf)'; then
    printf 'Description must contain trigger keywords (overnight/unattended/goal issue/nachtlauf).\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 3 — NO `model:` key in frontmatter (single-source model policy, #98)
#     Codex directive D2: model selection is owned by c-bpm-sk-llm-selection.
# ------------------------------------------------------------------

@test "3: frontmatter contains NO 'model:' key (single-source model policy)" {
  require_cmd
  local bad
  bad="$(frontmatter "${CMD}" | grep -n '^model:' || true)"
  if [[ -n "${bad}" ]]; then
    printf 'Frontmatter must NOT hard-wire a model. Found:\n%s\n' "${bad}" >&2
    printf 'Model selection is owned solely by c-bpm-sk-llm-selection.\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 4 — no numeric model version pin anywhere in the command
# ------------------------------------------------------------------

@test "4: no numeric model version pin (fable/codex + digit) in the command" {
  require_cmd
  local bad
  bad="$(grep -niE '(fable|codex)[- ]?[0-9]' "${CMD}" || true)"
  if [[ -n "${bad}" ]]; then
    printf 'Hard-wired numeric model version found in the command:\n%s\n' "${bad}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 5 — defers model selection to the single source of truth
# ------------------------------------------------------------------

@test "5: references c-bpm-sk-llm-selection as the model authority" {
  require_cmd
  if ! grep -qF 'c-bpm-sk-llm-selection' "${CMD}"; then
    printf 'Command must reference c-bpm-sk-llm-selection for all model selection.\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 6 — final devil's-advocate pass is wired in by exact skill name
# ------------------------------------------------------------------

@test "6: references c-bpm-sk-devils-advocate for the final review pass" {
  require_cmd
  if ! grep -qF 'c-bpm-sk-devils-advocate' "${CMD}"; then
    printf 'Command must reference c-bpm-sk-devils-advocate (created by #113, same branch).\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 7 — batch execution delegates to the existing team command
# ------------------------------------------------------------------

@test "7: delegates batch execution to c-bpm-cm-openissues-team" {
  require_cmd
  if ! grep -qF 'c-bpm-cm-openissues-team' "${CMD}"; then
    printf 'Command must delegate batch execution to /c-bpm-cm-openissues-team.\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 8 — scope contract: $ARGUMENTS plus default milestone `new`
# ------------------------------------------------------------------

@test "8: scope contract uses \$ARGUMENTS and defaults to milestone 'new'" {
  require_cmd
  if ! grep -qF '$ARGUMENTS' "${CMD}"; then
    printf 'Command must accept scope via $ARGUMENTS.\n' >&2
    return 1
  fi
  # One explicit default-scope line: it must say "default", "milestone" and "new"
  # together — not three unrelated mentions scattered across the file.
  if ! grep -i 'default' "${CMD}" | grep -i 'milestone' | grep -qiE '\bnew\b'; then
    printf 'Command must carry ONE explicit default-scope line naming default + milestone + new.\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 9 — autonomy contract: never ask; no blocking wait for user confirmation
# ------------------------------------------------------------------

@test "9: autonomy contract present (never ask the user, no blocking wait)" {
  require_cmd
  if ! grep -qiE 'never asks? the user' "${CMD}"; then
    printf 'Autonomy contract missing: the command must state it NEVER asks THE USER.\n' >&2
    return 1
  fi
  local hits bad=""
  hits="$(grep -niE 'wait(s|ed|ing)? for (the )?user (confirmation|approval)' "${CMD}" || true)"
  if [[ -n "${hits}" ]]; then
    # Only a negation that PRECEDES the phrase on the SAME line makes the mention
    # harmless ("never waits for user confirmation"). Trailing/loose qualifiers
    # ("override prior autonomy and wait for user confirmation") do not.
    bad="$(printf '%s\n' "${hits}" \
          | grep -viE "(never|does not|do not|don.t|without)[[:space:]].*wait(s|ed|ing)? for (the )?user (confirmation|approval)" || true)"
  fi
  if [[ -n "${bad}" ]]; then
    printf 'Blocking user-confirmation instruction found (breaks unattended run):\n%s\n' "${bad}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 10 — direct-to-main commit contract (PC-2, ratified precedence)
# ------------------------------------------------------------------

@test "10: direct-to-main contract (one commit per issue, push to main, no PRs)" {
  require_cmd
  local missing="" commit_ctx
  # 'one commit per issue' must sit in an actual commit/push context, not in a
  # stray prose line elsewhere in the document.
  commit_ctx="$(grep -i -B1 -A1 'one commit per issue' "${CMD}" || true)"
  if [[ -z "${commit_ctx}" ]] || ! printf '%s\n' "${commit_ctx}" | grep -qiE '(push|main|git commit)'; then
    missing="${missing} 'one commit per issue' in commit/push/main context"
  fi
  grep -qiE '(direct(ly)?[- ]to[- ](the )?main|push(es|ed)? to (the )?main|commit(s|ted)? (direct(ly)?)? ?to (the )?main)' "${CMD}" \
    || missing="${missing} direct-to-main push statement"
  grep -qiE 'no (PRs?|pull requests?)' "${CMD}" || missing="${missing} 'no PRs' statement"
  if [[ -n "${missing}" ]]; then
    printf 'Direct-to-main contract incomplete, missing:%s\n' "${missing}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 11 — DoD gate: test-approved required, DONE stays human-only
# ------------------------------------------------------------------

@test "11: commit gate requires 'test-approved' and keeps DONE human-only" {
  require_cmd
  if ! grep -qF 'test-approved' "${CMD}"; then
    printf 'Command must gate commits on the test-approved milestone.\n' >&2
    return 1
  fi
  # 'human-only' must qualify DONE on the very same line.
  if ! grep -iE 'human[- ]only' "${CMD}" | grep -qiE '\bDONE\b'; then
    printf 'Command must state on one line that DONE is human-only (agents never set it).\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 12 — SUMMARY artifact filename pattern
# ------------------------------------------------------------------

@test "12: final report uses the SUMMARY-<YYYYMMDD>-<HHMM>.md filename pattern" {
  require_cmd
  if ! grep -qE "${SUMMARY_FILE_RE}" "${CMD}"; then
    printf 'Command must name the final report SUMMARY-<YYYYMMDD>-<HHMM>.md\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 13 — SUMMARY precedence statement (Codex directive D1)
#      Pairs with test 12: the side-car artifact is only allowed together
#      with its explicit, documented precedence over the issues-only rule.
# ------------------------------------------------------------------

@test "13: SUMMARY artifact carries the explicit precedence statement" {
  require_cmd
  local missing="" window
  window="$(summary_window "${CMD}")"
  if [[ -z "${window}" ]]; then
    printf 'No SUMMARY section found — cannot verify the precedence statement.\n' >&2
    return 1
  fi
  # Markers must sit INSIDE the SUMMARY section, not anywhere in the document.
  printf '%s\n' "${window}" | grep -qiF 'takes precedence' || missing="${missing} 'takes precedence'"
  printf '%s\n' "${window}" | grep -qiF 'authoritative'    || missing="${missing} 'authoritative'"
  printf '%s\n' "${window}" | grep -qiE 'issue comments?'  || missing="${missing} 'issue comment'"
  if [[ -n "${missing}" ]]; then
    printf 'SUMMARY precedence block incomplete, missing marker(s):%s\n' "${missing}" >&2
    printf 'Required: #112 spec takes precedence for this single artifact; Issues stay\n' >&2
    printf 'authoritative; every per-issue fact is posted as an issue comment FIRST.\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# 14 — DoD is the loop exit condition, with a documented-blocked escape
# ------------------------------------------------------------------

@test "14: loop exit condition is DoD-met or documented-blocked" {
  require_cmd
  if ! grep -iE '(exit|terminat|stop|end)' "${CMD}" | grep -qiE '\bDoD\b|definition of done'; then
    printf 'Loop exit condition must be stated in terms of the DoD.\n' >&2
    return 1
  fi
  # The escape hatch must be the literal `documented-blocked` state, and it must
  # appear in exit/stall context — not as a stray "blocked" anywhere in the file.
  if ! grep -iE '(exit|stall|terminat|stop|end of)' "${CMD}" | grep -qiF 'documented-blocked'; then
    printf 'Loop must name the literal documented-blocked escape in its exit/stall condition.\n' >&2
    return 1
  fi
}
