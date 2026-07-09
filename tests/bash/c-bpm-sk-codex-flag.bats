#!/usr/bin/env bats
#
# c-bpm-sk-codex-flag.bats - Guard the single-source model policy (Issue #98)
# Run with: bats tests/bash/c-bpm-sk-codex-flag.bats
#
# History:
#   Issue #44 (codex CLI 0.94) added `-m gpt-5.2` to every codex invocation
#   because ChatGPT-auth accounts could not use the CLI default model.
#   Issue #98 REVERSES that: on the current Codex CLI (0.128.0, default model
#   gpt-5.4) the default works under ChatGPT auth, and `c-bpm-sk-llm-selection`
#   is now the single source of truth for model selection. Every codex
#   invocation MUST be bare (no `-m`), and no skill/command may hard-wire a
#   Codex model version or a numeric Opus version. This suite locks that in.
#
#   NOTE: the guard regexes below intentionally contain "gpt-5"; this test file
#   lives under tests/ (outside my/), so it does not trip the acceptance grep
#   `grep -rn 'gpt-5' my/ = 0`.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"

# ------------------------------------------------------------------
# Acceptance 1: no hard-wired Codex model version anywhere under my/
# ------------------------------------------------------------------

@test "no 'gpt-5' model reference anywhere under my/ (single-source policy)" {
  cd "${REPO_ROOT}"
  local bad
  bad="$(grep -rn -- 'gpt-5' my/ || true)"
  if [[ -n "${bad}" ]]; then
    printf 'Hard-wired Codex model reference found under my/:\n%s\n' "${bad}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# Belt-and-braces: no bare `-m <model>` pin on any codex invocation
# ------------------------------------------------------------------

@test "no 'codex exec ... -m' model pin anywhere under my/" {
  cd "${REPO_ROOT}"
  local bad
  # Model-anchored so a multiline (backslash-continued) `-m gpt-5.4` or a future
  # family (`-m claude-...`, `-m o4-...`) is caught even when `-m` is not on the
  # same line as `codex exec`.
  bad="$(grep -rnE -- '[[:space:]]-m[[:space:]]+(gpt|o[0-9]|claude|opus|gemini|sonnet|haiku)' my/ || true)"
  if [[ -n "${bad}" ]]; then
    printf 'Codex invocation with a hard-wired -m model pin found under my/:\n%s\n' "${bad}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# Acceptance 2: no numeric Opus version pin anywhere under my/
# ------------------------------------------------------------------

@test "no numeric 'Opus N' version pin anywhere under my/" {
  cd "${REPO_ROOT}"
  local bad
  # Any numeric Opus pin — Opus 4, Opus 4.8, Opus 5, opus-4-6 — not just 4.x.
  # 'newest Opus' / 'model: opus' (no adjacent digit) stay allowed.
  bad="$(grep -rniE -- 'opus[- ]?[0-9]' my/ || true)"
  if [[ -n "${bad}" ]]; then
    printf 'Hard-wired numeric Opus version pin found under my/:\n%s\n' "${bad}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# Review gates must still be documented (no accidental deletion)
# ------------------------------------------------------------------

@test "at least one bare 'codex exec --skip-git-repo-check' invocation remains under my/" {
  cd "${REPO_ROOT}"
  local n
  n="$(grep -rc -- 'codex exec --skip-git-repo-check' my/ | awk -F: '{s+=$2} END{print s+0}')"
  if (( n == 0 )); then
    printf 'Expected at least one documented codex review gate under my/, found none.\n' >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# The single source of truth exists
# ------------------------------------------------------------------

@test "c-bpm-sk-llm-selection contains the Model Version Policy block" {
  local f="${REPO_ROOT}/my/skills/c-bpm-sk-llm-selection/SKILL.md"
  if [[ ! -f "${f}" ]]; then
    printf 'c-bpm-sk-llm-selection/SKILL.md not found.\n' >&2
    return 1
  fi
  if ! grep -qiF "Model Version Policy" "${f}"; then
    printf 'Model Version Policy block missing from c-bpm-sk-llm-selection/SKILL.md.\n' >&2
    return 1
  fi
}
