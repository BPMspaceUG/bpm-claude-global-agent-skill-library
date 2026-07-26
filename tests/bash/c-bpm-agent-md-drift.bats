#!/usr/bin/env bats
#
# c-bpm-agent-md-drift.bats — drift guard for the CLAUDE.md / agent.md split
# (BPMspaceUG/bpm-claude-global-agent-skill-library#95).
#
# #95 originally proposed four parallel context files. Verification of the
# premise found only ONE loader — my/commands/c-bpm-cm-openissues-team.md
# Phase 0d reads CLAUDE.md, SHARED_TASK_NOTES.md and agent.md — and no loader
# at all for gemini.md or vibe.md. Files nothing reads are duplication plus
# drift, which is exactly what bit this repo in #114.
#
# So the shipped shape is: common content in CLAUDE.md, Codex-specific deltas
# in agent.md, nothing duplicated across the two. This suite pins that shape.
# Run with: bats tests/bash/c-bpm-agent-md-drift.bats

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
CLAUDE_MD="${REPO_ROOT}/CLAUDE.md"
AGENT_MD="${REPO_ROOT}/agent.md"
LOADER="${REPO_ROOT}/my/commands/c-bpm-cm-openissues-team.md"

@test "both context files exist" {
  [[ -f "${CLAUDE_MD}" ]] || { echo "missing ${CLAUDE_MD}"; return 1; }
  [[ -f "${AGENT_MD}" ]]  || { echo "missing ${AGENT_MD}"; return 1; }
}

@test "the loader reads exactly the three context files that exist" {
  # The premise check for #95: agent.md is loaded, gemini.md and vibe.md are
  # not — so they must not be created.
  grep -q 'agent\.md' "${LOADER}" || { echo "loader no longer reads agent.md"; return 1; }
  grep -q 'CLAUDE\.md' "${LOADER}" || { echo "loader no longer reads CLAUDE.md"; return 1; }
  grep -q 'SHARED_TASK_NOTES\.md' "${LOADER}" || { echo "loader no longer reads SHARED_TASK_NOTES.md"; return 1; }
}

@test "no unloaded context files were created (gemini.md / vibe.md)" {
  for f in gemini.md vibe.md GEMINI.md VIBE.md; do
    if [[ -e "${REPO_ROOT}/${f}" ]]; then
      echo "${f} exists but nothing loads it — duplication + drift (#95, #114)."
      return 1
    fi
  done
}

@test "CLAUDE.md retains the common rules" {
  # These sections are the shared content. If any of them migrated into
  # agent.md, the split inverted.
  local required=(
    '## Repository Purpose'
    '## Skills Are Absolute'
    '## Architecture'
    '## Enforcement: Hooks, Not Wrappers'
    'c-{org}-{type}-{name}'
  )
  local want
  for want in "${required[@]}"; do
    grep -qF -- "${want}" "${CLAUDE_MD}" || { echo "CLAUDE.md lost: ${want}"; return 1; }
  done
}

@test "CLAUDE.md states the split contract and names agent.md" {
  grep -qF -- '**agent.md**' "${CLAUDE_MD}" || { echo "CLAUDE.md does not describe agent.md"; return 1; }
  grep -qF -- 'gemini.md' "${CLAUDE_MD}" || { echo "CLAUDE.md does not record why gemini.md/vibe.md are absent"; return 1; }
}

@test "agent.md holds only Codex-specific sections" {
  local required=(
    '## Role'
    '## Review input'
    '## Verdict boundaries'
  )
  local want
  for want in "${required[@]}"; do
    grep -qF -- "${want}" "${AGENT_MD}" || { echo "agent.md lost: ${want}"; return 1; }
  done

  # CLAUDE.md's own section titles must NOT reappear as headings in agent.md.
  local forbidden=(
    '## Repository Purpose'
    '## Skills Are Absolute'
    '## Architecture'
    '## Installation'
    '## Target Technology Stack'
    '## Enforcement: Hooks, Not Wrappers'
  )
  for want in "${forbidden[@]}"; do
    if grep -qF -- "${want}" "${AGENT_MD}"; then
      echo "agent.md duplicates the CLAUDE.md section '${want}' — that duplication IS the drift #95 must not create."
      return 1
    fi
  done
}

@test "no mandatory block is duplicated verbatim across CLAUDE.md and agent.md" {
  # The real drift guard: any substantial line present in both files is a
  # copy that will diverge. Trivial/structural lines are excluded.
  local dupes
  dupes="$(
    grep -vE '^\s*$|^\s*```|^\s*[-|]+\s*$' "${CLAUDE_MD}" \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
      | awk 'length($0) >= 45' | sort -u > "${BATS_TEST_TMPDIR}/claude.lines"
    grep -vE '^\s*$|^\s*```|^\s*[-|]+\s*$' "${AGENT_MD}" \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
      | awk 'length($0) >= 45' | sort -u > "${BATS_TEST_TMPDIR}/agent.lines"
    comm -12 "${BATS_TEST_TMPDIR}/claude.lines" "${BATS_TEST_TMPDIR}/agent.lines"
  )"
  if [[ -n "${dupes}" ]]; then
    echo "Duplicated between CLAUDE.md and agent.md — put it in ONE file:"
    printf '%s\n' "${dupes}"
    return 1
  fi
}

@test "agent.md pins no model version (single-source model policy, #98)" {
  # Same rule readme-guards.bats enforces for README.md: the ladder and every
  # model choice live in c-bpm-sk-llm-selection, nowhere else (#119).
  local hits
  hits="$(grep -nEi 'gpt-[0-9]|o[0-9]-(mini|preview)|codex-[0-9]|claude-(opus|sonnet|haiku)-[0-9]|gemini-[0-9]' "${AGENT_MD}" || true)"
  if [[ -n "${hits}" ]]; then
    echo "agent.md pins a model version:"
    printf '%s\n' "${hits}"
    return 1
  fi
}

@test "agent.md points at CLAUDE.md rather than restating it" {
  grep -qF -- 'CLAUDE.md' "${AGENT_MD}" || { echo "agent.md does not reference CLAUDE.md"; return 1; }
  # Codex-specific by construction: it must name the single sanctioned call
  # site instead of describing an invocation of its own.
  grep -qF -- 'c-bpm-sk-devils-advocate' "${AGENT_MD}"
}
