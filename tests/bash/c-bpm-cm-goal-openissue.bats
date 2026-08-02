#!/usr/bin/env bats
#
# c-bpm-cm-goal-openissue.bats — guards for the goal-openissue command
# (Issue #152: Issues-only run records, Plan-Issue mechanism).
#
# All content assertions run on the COMMAND-AUTHORED region of the file: the
# stamped issue-comms block is stripped first. Its byte-identity is owned by
# issue-comms-anchor.bats and deliberately not re-tested here.
#
# These are prose-level guards: they pin that the obligations exist in the
# command text, not that a runner obeys them (behavioral E2E is #122).

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
CMD="${REPO_ROOT}/my/commands/c-bpm-cm-goal-openissue.md"

# Command-authored region: everything outside the stamped issue-comms block.
authored() {
  awk '
    /<!-- BEGIN issue-comms/ { p=1 }
    !p { print }
    /<!-- END issue-comms/   { p=0 }
  ' "${CMD}"
}

# Section slice: from a heading line to the next "## " heading.
section() { # <heading-regex>
  authored | awk -v h="$1" '
    $0 ~ h { p=1; print; next }
    p && /^## /  { p=0 }
    p { print }
  '
}

@test "command file exists" {
  [ -f "${CMD}" ]
}

# 1 — no side-car setup step
@test "#152/1: no 'mkdir -p decisions reviews' setup" {
  ! authored | grep -qF 'mkdir -p decisions reviews'
}

# 2 — no side-car obligations anywhere in the authored region
@test "#152/2: zero references to PLAN.md, decisions/, reviews/" {
  local hits
  hits="$(authored | grep -nE 'PLAN\.md|decisions/|reviews/' || true)"
  if [ -n "${hits}" ]; then
    printf 'side-car reference(s) in command-authored region:\n%s\n' "${hits}" >&2
    return 1
  fi
}

# 3 — no precedence carve-out
@test "#152/3: no PRECEDENCE carve-out section" {
  ! authored | grep -qiE '^## PRECEDENCE|mandated run artifacts'
}

# 4 — Plan-Issue mechanism present
@test "#152/4: Plan Issue mechanics (plan label, PLAN: prefix, new+enhancement, human-only close)" {
  local body
  body="$(authored)"
  echo "${body}" | grep -qF 'Plan Issue'
  echo "${body}" | grep -qF '`plan` label'
  echo "${body}" | grep -qF 'PLAN:'
  echo "${body}" | grep -qE 'milestone `new`.*`enhancement`|`enhancement`.*milestone `new`'
  echo "${body}" | grep -qiE 'clos.* Plan Issue.*human|human.*clos.* Plan Issue'
}

# 5 — scope exclusion, automatic path
@test "#152/5: SCOPE RESOLUTION excludes plan-labeled issues" {
  section '^## SCOPE RESOLUTION' | grep -qiE '`plan`.*(label|labeled).*(never|exclud)|(never|exclud).*`plan`'
}

# 6 — scope exclusion, explicit-issue-number path
@test "#152/6: ARGUMENTS path refuses an explicitly passed plan-labeled issue" {
  section '^## ARGUMENTS' | grep -qiE '`plan`.*(label|labeled).*(refus|orchestration|skip|never)'
}

# 7 — bidirectional dependency lines
@test "#152/7: per-issue plan comments must carry Depends on: and Blocks: lines" {
  local body
  body="$(authored)"
  echo "${body}" | grep -qF 'Depends on:'
  echo "${body}" | grep -qF 'Blocks:'
}

# 8 — amendment loop after scope-changing re-resolves
@test "#152/8: plan amendment loop (amendment comment, dependency updates, re-approval, score row per round)" {
  local body
  body="$(authored)"
  echo "${body}" | grep -qiF 'plan amendment'
  echo "${body}" | grep -qiE 'amendment.*(re-run|re-approv|plan gate)|(re-run|re-approv|plan gate).*amendment'
  echo "${body}" | grep -qiF 'score table'
  echo "${body}" | grep -qiE 'row per (gate )?round'
}

# 9 — mirroring rule
@test "#152/9: Plan-Issue decisions mirrored to each affected work issue" {
  authored | grep -qiE 'mirror.*(work issue|affected issue)'
}

# 10 — single->multi promotion rule
@test "#152/10: promotion rule (create Plan Issue when scope grows, seed it, backlink)" {
  local body
  body="$(section '^## BATCH PLANNING')"
  echo "${body}" | grep -qiF 'promot'
  echo "${body}" | grep -qiF 'seed'
  echo "${body}" | grep -qiF 'backlink'
}

# 11 — ensure-then-verify label creation, no || true
@test "#152/11: ensure-then-verify plan label; literal '|| true' absent; documented-blocked fallback" {
  local body
  body="$(authored)"
  echo "${body}" | grep -qiE 'verify.*label|label.*verif'
  echo "${body}" | grep -qF 'documented-blocked'
  ! echo "${body}" | grep -qF '|| true'
}

# 12 — stamped block still present (identity owned by issue-comms-anchor.bats)
@test "#152/12: stamped issue-comms block markers intact" {
  grep -qF '<!-- BEGIN issue-comms' "${CMD}"
  grep -qF '<!-- END issue-comms' "${CMD}"
}

@test "[#167] goal-openissue carries the NO MID-RUN CHECKPOINTS run-to-terminal contract" {
  grep -qF 'NO MID-RUN CHECKPOINTS' "$CMD"
  grep -qiF 'run ends ONLY when' "$CMD"
  grep -qiF 'finished batch is never a stopping point' "$CMD"
  grep -qiF 'Self-check before ending' "$CMD"
}

@test "[#167] goal-openissue explicitly forbids the shall-I-continue checkpoint" {
  grep -qiF 'shall I continue' "$CMD"
  grep -qiF 'is forbidden; the answer is always yes' "$CMD"
}

@test "[#167] no-arg GOAL is defined as ALL open issues (not an operator prioritisation question)" {
  grep -qiF 'No-arg GOAL means ALL open issues' "$CMD"
}
