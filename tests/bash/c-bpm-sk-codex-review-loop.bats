#!/usr/bin/env bats
#
# c-bpm-sk-codex-review-loop.bats - Guard against Issue #89 regression
# Run with: bats tests/bash/c-bpm-sk-codex-review-loop.bats
#
# Purpose:
#   Issue #89 documented a session-fabricated rule capping Codex review at 2
#   cycles per phase and escalating to the user. The corrected canonical rule
#   is the Producer-LLM <-> Codex-as-Judge loop until consensus, with no cycle
#   cap, no user inside the loop, and no third model for tiebreaking. This
#   suite locks in:
#     1. The corrected pattern is encoded in c-bpm-sk-llm-selection.
#     2. None of the in-scope files reintroduce the forbidden phrasings.
#     3. Non-Codex-Judge guard rails (substitute / one-at-a-time / never
#        tiebreaker) are present in c-bpm-sk-llm-selection.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

# In-scope files used across negative tests. Keep in sync with the scope
# of Issue #89.
IN_SCOPE_FILES=(
  "my/skills/c-bpm-sk-llm-selection/SKILL.md"
  "my/skills/c-bpm-sk-skill-creator/SKILL.md"
  "my/skills/c-bpm-sk-skill-optimizer/SKILL.md"
  "my/skills/c-bpm-sk-skill-optimizer/references/team-orchestration.md"
  "my/commands/c-bpm-cm-openissues-team.md"
)

LLM_SELECTION="${REPO_ROOT}/my/skills/c-bpm-sk-llm-selection/SKILL.md"

# Negation / forbidding context markers. A grep hit on a forbidden
# pattern is exempt if the SAME LINE also contains one of these words —
# that line is forbidding the pattern, not instructing it. The canonical
# c-bpm-sk-llm-selection skill must name the forbidden patterns to
# forbid them, so the regex tests have to allow that specific case.
#
# Markers were selected from the wording actually used in the rewritten
# skill ("No cycle cap", "Never a tiebreaker", "do not", "Inviting … to
# break a tie", "Running … as a co-Judge", "Imposing an artificial
# cycle cap", "Escalating a Codex rejection", "instead of", "fabricated",
# "are forbidden", "reintroduce", "skipping").
_NEGATION_RE='\b(no|not|never|none|forbidden|do not|must not|cannot|can'\''t|don'\''t|inviting|instead of|reintroduce|imposing|escalating|running|avoid|skipping|fabricated|abandon|abandonment)\b'

# ------------------------------------------------------------------
# Helper: assert a regex (ERE, case-insensitive) does NOT match in any
# in-scope file as an INSTRUCTION. A match is exempt if any of the
# 2 lines before, the matched line itself, or the 2 lines after
# contains a negation / forbidding marker (see _NEGATION_RE) — the
# canonical skill must name forbidden patterns to forbid them, and
# bullet wording sometimes spans multiple lines. Reports every
# remaining offender on failure.
# ------------------------------------------------------------------
_assert_no_match() {
  local label="$1"
  local pattern="$2"
  local offenders=()
  local rel f match_lines lineno window
  for rel in "${IN_SCOPE_FILES[@]}"; do
    f="${REPO_ROOT}/${rel}"
    if [[ ! -f "${f}" ]]; then
      offenders+=("${rel} (file not found)")
      continue
    fi
    # Collect line numbers of pattern matches.
    match_lines="$(grep -nEi "${pattern}" "${f}" 2>/dev/null | cut -d: -f1 || true)"
    [[ -z "${match_lines}" ]] && continue
    while IFS= read -r lineno; do
      [[ -z "${lineno}" ]] && continue
      # 5-line context window: 2 before, the match, 2 after.
      local lo=$(( lineno - 2 ))
      local hi=$(( lineno + 2 ))
      (( lo < 1 )) && lo=1
      window="$(sed -n "${lo},${hi}p" "${f}")"
      if grep -qiE "${_NEGATION_RE}" <<< "${window}"; then
        continue  # match is in forbidding context; not an offender
      fi
      # Real offender — record line and content.
      offenders+=("${rel}:${lineno}: $(sed -n "${lineno}p" "${f}")")
    done <<< "${match_lines}"
  done
  if (( ${#offenders[@]} > 0 )); then
    printf 'Forbidden pattern (%s) matched as instruction (no negation marker in 5-line window):\n' "${label}" >&2
    printf '  pattern: %s\n' "${pattern}" >&2
    printf '  %s\n' "${offenders[@]}" >&2
    return 1
  fi
}

# ==================================================================
# Test 1 - c-bpm-sk-llm-selection encodes the Producer<->Codex Judge loop
# ==================================================================

@test "c-bpm-sk-llm-selection encodes the Producer<->Codex Judge loop" {
  local missing=()
  local needle
  for needle in \
    "Producer" \
    "Judge" \
    "consensus" \
    "no cycle cap" \
    "Codex" \
    "Codex Review Loop"
  do
    if ! grep -qiF -- "${needle}" "${LLM_SELECTION}"; then
      missing+=("${needle}")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    printf 'Missing required keywords in c-bpm-sk-llm-selection/SKILL.md:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    return 1
  fi
}

# ==================================================================
# Test 2 - no numeric cycle cap anywhere in scope
# ==================================================================

@test "no in-scope file contains a numeric cycle cap" {
  _assert_no_match "max N cycles"        '\bmax [0-9]+ cycles?\b'
  _assert_no_match "cap at N"            '\bcap.{0,10}at [0-9]+\b'
  _assert_no_match "after N revisions"   '\bafter [0-9]+ (revisions?|cycles?|rounds?)\b'
  _assert_no_match "2/two cycles"        '\b(2|two) cycles?\b'
}

# ==================================================================
# Test 3 - no escalation of Codex rejection to the user
# ==================================================================

@test "no in-scope file escalates Codex rejection to the user" {
  _assert_no_match "escalate ... user" 'escalate.{0,40}user'
  _assert_no_match "user decides/breaks/judges/arbitrates ... tie/deadlock/conflict/rejection" \
    'user (decides|breaks|judges|arbitrates).{0,40}(tie|deadlock|conflict|rejection)'
}

# ==================================================================
# Test 4 - no third model invoked for tiebreaking
# ==================================================================

@test "no in-scope file invokes a third model for tiebreaking" {
  _assert_no_match "third model" '\bthird model\b'
  _assert_no_match "tiebreak"    'tiebreak'
  _assert_no_match "consult ... third/another model" \
    'consult.{0,30}(third|another).{0,15}model'
  _assert_no_match "break (the) tie" 'break.{0,15}(the )?tie'
}

# ==================================================================
# Test 5 - no abandoning Codex review without consensus
# ==================================================================

@test "no in-scope file allows abandoning Codex review without consensus" {
  _assert_no_match "abandon ... review/loop" 'abandon.{0,40}(review|loop)'
  _assert_no_match "timeout ... codex/review/judge" \
    '(timeout|time out).{0,40}(codex|review|judge)'
  _assert_no_match "give up ... consensus/review/loop" \
    'give up.{0,40}(consensus|review|loop)'
}

# ==================================================================
# Test 6 - old "Consensus Finding Workflow" heading is removed
# ==================================================================

@test "c-bpm-sk-llm-selection: old Consensus Finding Workflow heading is removed" {
  if grep -qF -- "## Consensus Finding Workflow" "${LLM_SELECTION}"; then
    printf 'Stale heading still present in c-bpm-sk-llm-selection/SKILL.md:\n' >&2
    printf '  ## Consensus Finding Workflow\n' >&2
    return 1
  fi
}

# ==================================================================
# Test 7 - Gemini-as-arbiter steps are removed
# ==================================================================

@test "c-bpm-sk-llm-selection: Gemini-as-arbiter steps are removed" {
  local present=()
  local needle
  for needle in \
    "Gemini receives both positions" \
    "Gemini proposes resolution" \
    "If no consensus → Orchestrator (Claude) decides"
  do
    if grep -qF -- "${needle}" "${LLM_SELECTION}"; then
      present+=("${needle}")
    fi
  done
  if (( ${#present[@]} > 0 )); then
    printf 'Stale Gemini-as-arbiter wording still present:\n' >&2
    printf '  %s\n' "${present[@]}" >&2
    return 1
  fi
}

# ==================================================================
# Test 8 - non-Codex Judge is never invoked as tiebreaker / co-Judge /
# second opinion, and the three guard-rail bullet phrases are present
# in c-bpm-sk-llm-selection.
# ==================================================================

@test "no in-scope file invokes a non-Codex Judge as tiebreaker, co-Judge, or second opinion" {
  _assert_no_match "non-Codex Judge as tiebreaker/co-Judge/second-opinion" \
    '(gemini|second.{0,5}judge|co.?judge|alternate model).{0,40}(tiebreak|tie.?break|break.{0,10}tie|second opinion|alongside codex|co.?judge|concurrent)'
  _assert_no_match "second opinion / co-Judge / co-review of Codex/Gemini/Judge" \
    '(second opinion|co.?judge|co.?review).{0,40}(codex|gemini|judge)'
  _assert_no_match "concurrent Judges"        'concurrent.{0,15}judges?\b'
  _assert_no_match "parallel Judges"          'parallel.{0,15}judges?\b'
  _assert_no_match "two judges"               'two judges'
  _assert_no_match "both judges/models review/judge" \
    'both (judges|models).{0,30}(review|judge)'

  # Positive assertion: c-bpm-sk-llm-selection must contain the three
  # guard-rail bullet phrases verbatim (case-insensitive fixed-string).
  local missing=()
  local needle
  for needle in \
    "Substitute, not co-Judge" \
    "One Judge at a time" \
    "Never a tiebreaker"
  do
    if ! grep -qiF -- "${needle}" "${LLM_SELECTION}"; then
      missing+=("${needle}")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    printf 'Missing non-Codex-Judge guard-rail bullet phrases in c-bpm-sk-llm-selection/SKILL.md:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    return 1
  fi
}
