#!/usr/bin/env bats
#
# c-bpm-sk-codex-invocation-hygiene.bats - Guard against Issue #94 regression
# Run with: bats tests/bash/c-bpm-sk-codex-invocation-hygiene.bats
#
# Purpose:
#   Issue #94: `codex exec` run from a login/rc-sourcing shell leaks profile
#   startup output (keychain / ssh-agent / curl) into Codex's captured output,
#   which Codex misreads as file content -> false-positive review verdicts.
#   The canonical fix is a sanitized, non-login invocation documented ONCE in
#   c-bpm-sk-llm-selection (the designated Codex authority). This suite locks in:
#     1. The sanitized-invocation section exists with all sanitizing tokens.
#     2. The section carries the #94 rationale.
#     3. No file under my/ introduces a login-shell codex invocation.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
LLM_SELECTION="${REPO_ROOT}/my/skills/c-bpm-sk-llm-selection/SKILL.md"

@test "c-bpm-sk-llm-selection exists" {
  [[ -f "${LLM_SELECTION}" ]]
}

@test "canonical invocation carries all sanitizing tokens (--noprofile, --norc, BASH_ENV)" {
  grep -qF -- "--noprofile" "${LLM_SELECTION}"
  grep -qF -- "--norc" "${LLM_SELECTION}"
  grep -qF -- "BASH_ENV" "${LLM_SELECTION}"
}

@test "canonical invocation documents the #94 leak rationale (keychain)" {
  grep -qiF "keychain" "${LLM_SELECTION}"
  grep -qF "#94" "${LLM_SELECTION}"
}

@test "no file under my/ invokes 'codex exec' from a login shell (bash -l / -lc)" {
  cd "${REPO_ROOT}"
  # An actual login-shell invocation has the login flag and 'codex exec' on the
  # same command line. The prose in the hygiene section that *forbids* 'bash -lc'
  # does not put 'codex exec' on that line, so it is not matched.
  local bad
  bad="$(grep -rnE "bash +-l[c ][^\\n]*codex exec" my/ || true)"
  if [[ -n "${bad}" ]]; then
    printf 'Login-shell codex invocation found under my/:\n%s\n' "${bad}" >&2
    return 1
  fi
}
