#!/usr/bin/env bats
#
# c-bpm-sk-codex-invocation-hygiene.bats - Guard against Issue #94 regression
# Run with: bats tests/bash/c-bpm-sk-codex-invocation-hygiene.bats
#
# Purpose:
#   Issue #94: `codex exec` run from a login/rc-sourcing shell leaks profile
#   startup output (keychain / ssh-agent / curl) into Codex's captured output,
#   which Codex misreads as file content -> false-positive review verdicts.
#   The canonical fix is a sanitized, non-login invocation that since #113 lives
#   in exactly TWO scoped files: c-bpm-sk-llm-selection (the policy) and
#   c-bpm-sk-devils-advocate (the operational skill every gate calls).
#   This suite locks in:
#     1. Both scoped skills exist.
#     2. Both carry every sanitizing token (--noprofile, --norc, BASH_ENV).
#     3. Both carry the canonical invocation as ONE CONTIGUOUS command — not
#        three unrelated tokens scattered across prose (the failure mode that
#        made a token-only grep give false confidence).
#     4. The two copies have not drifted apart.
#     5. The #94 rationale is documented.
#     6. No file under my/ introduces a login-shell codex invocation.

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
LLM_SELECTION="${REPO_ROOT}/my/skills/c-bpm-sk-llm-selection/SKILL.md"
DEVILS_ADVOCATE="${REPO_ROOT}/my/skills/c-bpm-sk-devils-advocate/SKILL.md"

# The canonical invocation, as a single logical command line. Any change here is
# a deliberate policy change and must be mirrored in both scoped skills.
CANONICAL_INVOCATION="env -u BASH_ENV -u ENV bash --noprofile --norc -c 'codex exec --skip-git-repo-check -s workspace-write -c sandbox_workspace_write.network_access=true 2>&1'"

# Join backslash-continued lines into single logical lines and collapse runs of
# whitespace, so a multi-line `... -c \` / `  'codex exec ...'` invocation is
# matched as the one contiguous command it actually is, while three separate
# prose mentions of the same tokens are not.
normalize_shell_lines() {
  sed -e ':a' -e '/\\$/{N;s/\\\n//;ta' -e '}' "$1" | tr '\t' ' ' | tr -s ' '
}

# --- existence ---------------------------------------------------------------

@test "c-bpm-sk-llm-selection exists" {
  [[ -f "${LLM_SELECTION}" ]]
}

@test "c-bpm-sk-devils-advocate exists" {
  [[ -f "${DEVILS_ADVOCATE}" ]]
}

# --- sanitizing tokens present in BOTH scoped skills -------------------------

@test "llm-selection carries all sanitizing tokens (--noprofile, --norc, BASH_ENV)" {
  grep -qF -- "--noprofile" "${LLM_SELECTION}"
  grep -qF -- "--norc" "${LLM_SELECTION}"
  grep -qF -- "BASH_ENV" "${LLM_SELECTION}"
}

@test "devils-advocate carries all sanitizing tokens (--noprofile, --norc, BASH_ENV)" {
  grep -qF -- "--noprofile" "${DEVILS_ADVOCATE}"
  grep -qF -- "--norc" "${DEVILS_ADVOCATE}"
  grep -qF -- "BASH_ENV" "${DEVILS_ADVOCATE}"
}

# --- contiguity: the tokens form ONE command, not scattered prose ------------

@test "llm-selection carries the canonical invocation as one contiguous command" {
  local got
  got="$(normalize_shell_lines "${LLM_SELECTION}" | grep -cF -- "${CANONICAL_INVOCATION}" || true)"
  if [[ "${got}" -lt 1 ]]; then
    printf 'Canonical invocation not found as a contiguous command in %s\nExpected: %s\n' \
      "${LLM_SELECTION}" "${CANONICAL_INVOCATION}" >&2
    return 1
  fi
}

@test "devils-advocate carries the canonical invocation as one contiguous command" {
  local got
  got="$(normalize_shell_lines "${DEVILS_ADVOCATE}" | grep -cF -- "${CANONICAL_INVOCATION}" || true)"
  if [[ "${got}" -lt 1 ]]; then
    printf 'Canonical invocation not found as a contiguous command in %s\nExpected: %s\n' \
      "${DEVILS_ADVOCATE}" "${CANONICAL_INVOCATION}" >&2
    return 1
  fi
}

@test "the contiguity matcher rejects scattered token mentions (matcher is not vacuous)" {
  # Regression guard for the guard: a file that merely name-drops --noprofile,
  # --norc and BASH_ENV in prose must NOT satisfy the contiguity assertion.
  local fixture_dir fixture
  fixture_dir="$(mktemp -d)"
  fixture="${fixture_dir}/scattered.md"
  cat >"${fixture}" <<'EOF'
Always pass --noprofile when you invoke the judge.
Also remember --norc, which is load-bearing.
And unset BASH_ENV first.
Then run codex exec --skip-git-repo-check as usual.
EOF
  # Token-only grep would pass on this file...
  grep -qF -- "--noprofile" "${fixture}"
  grep -qF -- "--norc" "${fixture}"
  grep -qF -- "BASH_ENV" "${fixture}"
  # ...but the contiguity matcher must reject it.
  local got
  got="$(normalize_shell_lines "${fixture}" | grep -cF -- "${CANONICAL_INVOCATION}" || true)"
  rm -rf "${fixture_dir}"
  if [[ "${got}" -ne 0 ]]; then
    printf 'Contiguity matcher is vacuous: it matched a scattered-prose fixture.\n' >&2
    return 1
  fi
}

# --- the two copies must not drift apart ------------------------------------

@test "the canonical invocation is identical in both scoped skills (no drift)" {
  local a b
  a="$(normalize_shell_lines "${LLM_SELECTION}" | grep -oF -- "${CANONICAL_INVOCATION}" | head -1)"
  b="$(normalize_shell_lines "${DEVILS_ADVOCATE}" | grep -oF -- "${CANONICAL_INVOCATION}" | head -1)"
  if [[ -z "${a}" || -z "${b}" || "${a}" != "${b}" ]]; then
    printf 'Canonical invocation drifted between scoped skills:\n  llm-selection:   %s\n  devils-advocate: %s\n' \
      "${a:-<missing>}" "${b:-<missing>}" >&2
    return 1
  fi
}

# --- rationale documented ---------------------------------------------------

@test "canonical invocation documents the #94 leak rationale (keychain)" {
  grep -qiF "keychain" "${LLM_SELECTION}"
  grep -qF "#94" "${LLM_SELECTION}"
}

@test "devils-advocate references the #94 rationale for the sanitizing tokens" {
  grep -qF "#94" "${DEVILS_ADVOCATE}"
}

# --- no login-shell invocation anywhere under my/ ---------------------------

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

# ==================================================================
# #162 - SoD reviewer confined to a throwaway worktree + tree-integrity backstop
# ==================================================================

@test "[#162] both Judge skills wrap the invocation in a throwaway detached worktree" {
  local f
  for f in "${LLM_SELECTION}" "${DEVILS_ADVOCATE}"; do
    grep -qF 'git worktree add' "$f"    || { echo "no worktree add in $f" >&2; return 1; }
    grep -qF -- '--detach' "$f"         || { echo "no --detach in $f" >&2; return 1; }
    grep -qF 'git worktree remove' "$f" || { echo "no worktree remove in $f" >&2; return 1; }
  done
}

@test "[#162] the Judge invocation is cd'd into the throwaway worktree in both skills" {
  grep -qF 'cd "$JUDGE_WT"' "${LLM_SELECTION}"
  grep -qF 'cd "$JUDGE_WT"' "${DEVILS_ADVOCATE}"
}

@test "[#162] both skills mandate the tree-integrity backstop reverting tracked AND untracked, with a loud fail" {
  local f
  for f in "${LLM_SELECTION}" "${DEVILS_ADVOCATE}"; do
    grep -qF 'git status --porcelain' "$f" || { echo "no snapshot in $f" >&2; return 1; }
    grep -qF 'git checkout -- .' "$f"       || { echo "no tracked revert in $f" >&2; return 1; }
    grep -qF 'git clean -fdq' "$f"          || { echo "no untracked cleanup in $f" >&2; return 1; }
    grep -qF 'TREE MUTATED' "$f"            || { echo "no loud fail in $f" >&2; return 1; }
    grep -qF '#162' "$f"                    || { echo "no #162 ref in $f" >&2; return 1; }
  done
}

@test "[#162] read-only is documented as non-viable because the Judge must run bats" {
  grep -qF 'read-only' "${LLM_SELECTION}"
  grep -qF '/tmp' "${LLM_SELECTION}"
  grep -qF 'bats' "${LLM_SELECTION}"
}

@test "[#162] the sanitized inner invocation survived the wrapper (no-drift regression)" {
  local a b
  a="$(normalize_shell_lines "${LLM_SELECTION}" | grep -cF -- "${CANONICAL_INVOCATION}" || true)"
  b="$(normalize_shell_lines "${DEVILS_ADVOCATE}" | grep -cF -- "${CANONICAL_INVOCATION}" || true)"
  [ "$a" -ge 1 ] && [ "$b" -ge 1 ]
}
