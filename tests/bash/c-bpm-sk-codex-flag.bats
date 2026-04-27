#!/usr/bin/env bats
#
# c-bpm-sk-codex-flag.bats - Guard against Issue #44 regression
# Run with: bats tests/bash/c-bpm-sk-codex-flag.bats
#
# Purpose:
#   codex CLI 0.94.0 defaults to gpt-5.2-codex which ChatGPT-auth accounts
#   cannot use. Every `codex exec --skip-git-repo-check` invocation in this
#   library MUST carry `-m gpt-5.2` so ChatGPT-auth users can execute the
#   Codex review gates. This suite guarantees the flag is present on every
#   invocation across every documented codex usage in my/.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

# Files that document or invoke `codex exec --skip-git-repo-check`.
# Keep this list in sync with the scope of Issue #44.
AFFECTED_FILES=(
  "my/skills/c-bpm-sk-auditor/SKILL.md"
  "my/skills/c-bpm-sk-auditor/references/codex-prompts.md"
  "my/skills/c-bpm-sk-skill-optimizer/SKILL.md"
  "my/skills/c-bpm-sk-skill-optimizer/references/team-orchestration.md"
  "my/skills/c-bpm-sk-skill-creator/SKILL.md"
  "my/skills/c-bpm-sk-release-ops/SKILL.md"
  "my/skills/c-bpm-sk-repo-scaffold/SKILL.md"
  "my/skills/c-bpm-sk-milestone-type/SKILL.md"
  "my/skills/c-bpm-sk-linux-archive/SKILL.md"
  "my/skills/c-bpm-sk-linux-audit/SKILL.md"
  "my/skills/c-bpm-sk-linux-admin/SKILL.md"
  "my/skills/c-bpm-sk-flightphp-pro/references/team-orchestration.md"
  "my/skills/c-bpm-sk-grill-claude-issue/SKILL.md"
  "my/skills/c-bpm-sk-grill-me-issue/SKILL.md"
  "my/skills/c-bpm-sk-grill-me/SKILL.md"
  "my/skills/c-bpm-sk-idea-merge/SKILL.md"
  "my/commands/c-bpm-cm-openissues-team.md"
  "my/commands/c-bpm-cm-refactor-repo.md"
  "my/commands/c-bpm-cm-skill-creator.md"
  "my/commands/c-bpm-cm-skill-optimizer.md"
)

# ------------------------------------------------------------------
# Per-file: every affected file carries at least one fixed invocation
# ------------------------------------------------------------------

@test "every affected file contains at least one 'codex exec --skip-git-repo-check -m gpt-5.2' invocation" {
  local missing=()
  for rel in "${AFFECTED_FILES[@]}"; do
    local f="${REPO_ROOT}/${rel}"
    if [[ ! -f "${f}" ]]; then
      missing+=("${rel} (file not found)")
      continue
    fi
    if ! grep -qF "codex exec --skip-git-repo-check -m gpt-5.2" "${f}"; then
      missing+=("${rel}")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    printf 'Missing fixed invocation in:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# Per-file: no file may contain a bare invocation without -m gpt-5.2
# ------------------------------------------------------------------

@test "no affected file contains a bare 'codex exec --skip-git-repo-check' without -m gpt-5.2" {
  local offenders=()
  for rel in "${AFFECTED_FILES[@]}"; do
    local f="${REPO_ROOT}/${rel}"
    [[ -f "${f}" ]] || continue
    # Lines that have the bare pattern but NOT the fixed pattern.
    local bad
    bad="$(grep -nF "codex exec --skip-git-repo-check" "${f}" \
           | grep -vF "codex exec --skip-git-repo-check -m gpt-5.2" || true)"
    if [[ -n "${bad}" ]]; then
      offenders+=("${rel}:"$'\n'"${bad}")
    fi
  done
  if (( ${#offenders[@]} > 0 )); then
    printf 'Bare codex invocations (missing -m gpt-5.2):\n' >&2
    printf '%s\n' "${offenders[@]}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# Repo-wide sweep: catches files newly added outside the scope list
# ------------------------------------------------------------------

@test "repo-wide: no 'codex exec --skip-git-repo-check' occurrence under my/ is missing -m gpt-5.2" {
  cd "${REPO_ROOT}"
  local bad
  bad="$(grep -rnF "codex exec --skip-git-repo-check" my/ \
         | grep -vF "codex exec --skip-git-repo-check -m gpt-5.2" || true)"
  if [[ -n "${bad}" ]]; then
    printf 'Bare codex invocations found under my/:\n%s\n' "${bad}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# Idempotency: the fix must not have produced doubled -m flags
# ------------------------------------------------------------------

@test "no doubled '-m gpt-5.2 -m gpt-5.2' anywhere under my/" {
  cd "${REPO_ROOT}"
  local dup
  dup="$(grep -rnF -- "-m gpt-5.2 -m gpt-5.2" my/ || true)"
  if [[ -n "${dup}" ]]; then
    printf 'Doubled -m flag:\n%s\n' "${dup}" >&2
    return 1
  fi
}
