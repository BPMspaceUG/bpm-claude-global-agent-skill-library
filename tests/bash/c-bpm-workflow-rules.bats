#!/usr/bin/env bats
#
# c-bpm-workflow-rules.bats - Content guards for the two team commands
# Run with: bats tests/bash/c-bpm-workflow-rules.bats
#
# Covers the command/shared-doc half of four issues:
#   #116 - no blocking user-confirmation gate (Codex is the gate authority)
#   #125 - landing is direct-to-main; no branch/PR landing instructions
#   #120 - teammate lifecycle: shut down after delivery, verify termination
#          before spawning a replacement, never reuse a finished teammate
#   #134 - every finding is filed as an Issue immediately, never "ask first"
#
# Scope: static content guards on my/commands/c-bpm-cm-openissues-team.md and
# my/commands/c-bpm-cm-refactor-repo.md ONLY. Every grep is scoped to those two
# file paths, never to a directory tree, so the patterns cannot match this file.
#
# Deliberately NOT covered here (would be duplication):
#   - issue milestone/type enforcement -> c-bpm-sk-issue-write-gate.bats
#   - the goal-issue command's own contract -> c-bpm-cm-goal-issue.bats
#   - the stamped issue-comms block -> issue-comms-anchor.bats

set -u

setup() {
  REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  TEAM="${REPO_ROOT}/my/commands/c-bpm-cm-openissues-team.md"
  REFACTOR="${REPO_ROOT}/my/commands/c-bpm-cm-refactor-repo.md"
  CMDS=("${TEAM}" "${REFACTOR}")
  REFS=( "${REPO_ROOT}"/my/skills/*/references/team-orchestration.md )
  LINUX_ADMIN="${REPO_ROOT}/my/skills/c-bpm-sk-linux-admin/SKILL.md"
}

require_cmds() {
  local f
  for f in "${CMDS[@]}"; do
    if [[ ! -f "${f}" ]]; then
      printf 'Command file not found: %s\n' "${f}" >&2
      return 1
    fi
  done
}

require_refs() {
  [ "${#REFS[@]}" -ge 2 ] && [ -f "${REFS[0]}" ] || { echo "REFS glob resolved to <2 files: ${REFS[*]}"; return 1; }
}

# ------------------------------------------------------------------
# #116 — no blocking user-confirmation gate
# ------------------------------------------------------------------

@test "116: neither team command blocks on user confirmation" {
  require_cmds
  local f hits bad="" all=""
  for f in "${CMDS[@]}"; do
    hits="$(grep -niE 'wait([[:alpha:]]*)? for (the )?user (confirmation|approval)' "${f}" || true)"
    [[ -z "${hits}" ]] && continue
    # Only a negation PRECEDING the phrase on the SAME line is harmless
    # ("never wait for user confirmation"). Same rule as c-bpm-cm-goal-issue.bats
    # test 9 — applied here to the two team commands, which that file never reads.
    bad="$(printf '%s\n' "${hits}" \
          | grep -viE "(never|not|don.t|without)[[:space:]].*wait([[:alpha:]]*)? for (the )?user (confirmation|approval)" || true)"
    [[ -n "${bad}" ]] && all="${all}${f}:\n${bad}\n"
  done
  if [[ -n "${all}" ]]; then
    printf 'Blocking user-confirmation gate found (violates #116 — Codex gates, not the operator):\n' >&2
    printf "%b" "${all}" >&2
    return 1
  fi
}

@test "116: neither team command tells the lead to ask the user for confirmation" {
  require_cmds
  local f hits bad="" all=""
  for f in "${CMDS[@]}"; do
    hits="$(grep -niE 'ask(s|ing)? the user (for )?(confirmation|approval|to approve|whether)' "${f}" || true)"
    [[ -z "${hits}" ]] && continue
    bad="$(printf '%s\n' "${hits}" \
          | grep -viE "(never|not|don.t)[[:space:]].*ask(s|ing)? the user" || true)"
    [[ -n "${bad}" ]] && all="${all}${f}:\n${bad}\n"
  done
  if [[ -n "${all}" ]]; then
    printf 'Command instructs the lead to ask the user for confirmation (violates #116):\n' >&2
    printf "%b" "${all}" >&2
    return 1
  fi
}

@test "116: both team commands state the never-ask autonomy contract" {
  require_cmds
  local f missing=""
  for f in "${CMDS[@]}"; do
    grep -qiE 'never (asks?|waits?)' "${f}" || missing="${missing} ${f}"
  done
  if [[ -n "${missing}" ]]; then
    printf 'Autonomy contract (never asks / never waits) missing in:%s\n' "${missing}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# #125 — direct to main, no branch-and-PR landing
# ------------------------------------------------------------------

@test "125: refactor command carries no branch/PR landing instruction" {
  require_cmds
  local hits bad=""
  # Landing verbs only. Bare mentions such as "Check open PRs for in-flight work"
  # stay legal — this guard targets instructions to CREATE or MERGE one.
  hits="$(grep -niE '(create|raise|submit|file)[[:alpha:]]* (a |an |the )?(PR|pull request)|merge[[:alpha:]]* (the )?(PRs?|pull requests?)|create (a )?feature branch|refactor/<teammate-name>' "${REFACTOR}" || true)"
  if [[ -n "${hits}" ]]; then
    # A line that FORBIDS the shape is the fix, not the violation.
    bad="$(printf '%s\n' "${hits}" | grep -viE '(never|no |not |does not|do not|don.t)' || true)"
  fi
  if [[ -n "${bad}" ]]; then
    printf 'Branch/PR landing instruction found (violates #125 — this repo pushes direct to main):\n%s\n' "${bad}" >&2
    return 1
  fi
}

@test "125: refactor command states direct-to-main landing with no PRs" {
  require_cmds
  local missing=""
  grep -qiE '(direct(ly)?[- ]to[- ](the )?.?main|push(es|ed)? (straight |directly )?to (the )?.?main)' "${REFACTOR}" \
    || missing="${missing} direct-to-main push statement"
  grep -qiE 'no (pull requests?|PRs?)' "${REFACTOR}" \
    || missing="${missing} 'no pull requests' statement"
  grep -qiF 'one commit per issue' "${REFACTOR}" \
    || missing="${missing} 'one commit per issue'"
  grep -qiE 'no feature branch' "${REFACTOR}" \
    || missing="${missing} 'no feature branch' statement"
  if [[ -n "${missing}" ]]; then
    printf 'Direct-to-main landing contract incomplete in %s, missing:%s\n' "${REFACTOR}" "${missing}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# #120 — teammate lifecycle
# ------------------------------------------------------------------

@test "120: both team commands require shutdown after delivery" {
  require_cmds
  local f missing="" ctx
  for f in "${CMDS[@]}"; do
    # "shut down / terminate" must sit in the same sentence-window as "deliver".
    ctx="$(grep -iE -A1 '(shut ?down|terminate)' "${f}" || true)"
    printf '%s\n' "${ctx}" | grep -qiE 'deliver' || missing="${missing} ${f}"
  done
  if [[ -n "${missing}" ]]; then
    printf 'Missing shutdown-after-delivery guidance (#120) in:%s\n' "${missing}" >&2
    return 1
  fi
}

@test "120: both team commands require verifying termination before a replacement spawn" {
  require_cmds
  local f missing=""
  for f in "${CMDS[@]}"; do
    grep -iE '(verify|confirm)' "${f}" \
      | grep -qiE 'terminat|(is )?actually gone|shut ?down' \
      || missing="${missing} ${f}"
  done
  if [[ -n "${missing}" ]]; then
    printf 'Missing verify-termination-before-replacement guidance (#120) in:%s\n' "${missing}" >&2
    return 1
  fi
}

@test "120: both team commands warn that messaging a finished teammate can silently no-op" {
  require_cmds
  local f missing="" win
  for f in "${CMDS[@]}"; do
    win="$(grep -iE -A3 'SendMessage' "${f}" || true)"
    printf '%s\n' "${win}" | grep -qiE 'no-?op|silent' || missing="${missing} ${f}"
  done
  if [[ -n "${missing}" ]]; then
    printf 'Missing silent-no-op warning for messaging a finished teammate (#120/#132) in:%s\n' "${missing}" >&2
    return 1
  fi
}

@test "120: both team commands prefer a fresh spawn over reusing a finished teammate" {
  require_cmds
  local f missing=""
  for f in "${CMDS[@]}"; do
    grep -qiE 'never reuse a teammate' "${f}" || missing="${missing} ${f}"
  done
  if [[ -n "${missing}" ]]; then
    printf 'Missing never-reuse-a-finished-teammate rule (#120) in:%s\n' "${missing}" >&2
    return 1
  fi
}

# ------------------------------------------------------------------
# #134 — findings become issues, immediately, without asking
# ------------------------------------------------------------------

@test "134: both team commands state that every finding becomes an Issue immediately" {
  require_cmds
  local f missing="" ctx
  for f in "${CMDS[@]}"; do
    ctx="$(grep -iE -A1 'every finding becomes a( github)? issue' "${f}" || true)"
    printf '%s\n' "${ctx}" | grep -qiE 'immediate' || missing="${missing} ${f}"
  done
  if [[ -n "${missing}" ]]; then
    printf 'Missing "every finding becomes a GitHub Issue immediately" rule (#134) in:%s\n' "${missing}" >&2
    return 1
  fi
}

@test "134: neither team command defers or asks before filing a finding" {
  require_cmds
  local f hits bad all=""
  for f in "${CMDS[@]}"; do
    bad=""
    # Group A — phrases that park a finding for a human decision. No exemption:
    # they carry their own negation ("do NOT create them yet"), so a blanket
    # negation filter would swallow exactly the wording this guard must catch.
    bad="$(grep -niE "create them yet|user decides|for (the )?user to approve|awaiting approval|potential NEW issues" "${f}" || true)"
    # Group B — "ask ... whether to file", which a rule may legitimately forbid.
    # Only a negation PRECEDING it on the SAME line makes the mention harmless.
    hits="$(grep -niE 'ask(s|ing)? the user (whether|if) to (file|create|open)' "${f}" || true)"
    if [[ -n "${hits}" ]]; then
      hits="$(printf '%s\n' "${hits}" \
             | grep -viE "(never|not|don.t)[[:space:]].*ask(s|ing)? the user (whether|if) to" || true)"
      bad="${bad}${hits:+
${hits}}"
    fi
    [[ -n "${bad}" ]] && all="${all}${f}:\n${bad}\n"
  done
  if [[ -n "${all}" ]]; then
    printf 'Findings are parked for user approval instead of filed (violates #134):\n' >&2
    printf "%b" "${all}" >&2
    return 1
  fi
}

@test "159: references glob resolves to the team-orchestration reference files" {
  require_refs
}

@test "159: no team-orchestration reference blocks on user confirmation (#116 extended)" {
  require_refs
  local f hits bad="" all=""
  for f in "${REFS[@]}"; do
    hits="$(grep -niE 'wait([[:alpha:]]*)? for (the )?user (confirmation|approval)' "${f}" || true)"
    [[ -z "${hits}" ]] && continue
    bad="$(printf '%s\n' "${hits}" | grep -viE "(never|not|don.t|without)[[:space:]].*wait([[:alpha:]]*)? for (the )?user (confirmation|approval)" || true)"
    [[ -n "${bad}" ]] && all="${all}${f}:\n${bad}\n"
  done
  if [[ -n "${all}" ]]; then printf 'Blocking user-confirmation gate in a reference (violates #116/#159):\n' >&2; printf "%b" "${all}" >&2; return 1; fi
}

@test "159: each team-orchestration reference states the never-wait autonomy contract" {
  require_refs
  local f missing=""
  for f in "${REFS[@]}"; do
    grep -qiE 'never (asks?|waits?)' "${f}" || missing="${missing} ${f}"
  done
  if [[ -n "${missing}" ]]; then printf 'Autonomy contract missing in:%s\n' "${missing}" >&2; return 1; fi
}

@test "159: guard bites — a reference with a blocking wait is flagged (non-vacuous)" {
  local d f; d="$(mktemp -d)"; f="$d/team-orchestration.md"
  printf 'STOP and WAIT for user confirmation before spawning teammates.\n' > "$f"
  local hits bad
  hits="$(grep -niE 'wait([[:alpha:]]*)? for (the )?user (confirmation|approval)' "$f" || true)"
  bad="$(printf '%s\n' "$hits" | grep -viE "(never|not|don.t|without)[[:space:]].*wait([[:alpha:]]*)? for (the )?user (confirmation|approval)" || true)"
  rm -rf "$d"
  [[ -n "$bad" ]]
}

@test "[#165] every pizza-sim cross-repo ref in openissues-team is qualified (no bare local-style #id)" {
  local id total qual
  for id in 243 245 246 273; do
    total="$(grep -oE "#${id}([^0-9]|\$)" "$TEAM" | wc -l | tr -d ' ')"
    qual="$(grep -oE "pizza-sim#${id}([^0-9]|\$)" "$TEAM" | wc -l | tr -d ' ')"
    if [ "$total" -ne "$qual" ]; then echo "bare #${id} present in $TEAM (total=$total qual=$qual)"; return 1; fi
  done
}

@test "[#165] guard bites: a bare pizza-sim id is flagged, a qualified one is not" {
  local d bare good; d="$(mktemp -d)"
  printf '(#273)\n' > "$d/bad.md"; printf '(pizza-sim#273)\n' > "$d/ok.md"
  bare="$(grep -oE '#273([^0-9]|$)' "$d/bad.md" | wc -l)"; local bq; bq="$(grep -oE 'pizza-sim#273([^0-9]|$)' "$d/bad.md" | wc -l)"
  good="$(grep -oE '#273([^0-9]|$)' "$d/ok.md" | wc -l)"; local gq; gq="$(grep -oE 'pizza-sim#273([^0-9]|$)' "$d/ok.md" | wc -l)"
  rm -rf "$d"
  [ "$bare" -ne "$bq" ] && [ "$good" -eq "$gq" ]
}

@test "[#163] openissues-team pins the one-issue-one-invocation-one-verdict rule" {
  grep -qiF 'One issue, one invocation, one verdict' "$TEAM"
  grep -qiF 'never once per bundle' "$TEAM"
  grep -qiF 'only to the issue it reviewed' "$TEAM"
  grep -qiF 'Copying a verdict across a bundle is' "$TEAM"
  grep -qiF 'forbidden: it awards a milestone on evidence about a different issue' "$TEAM"
  grep -qiF 'Every gate prompt names the issue under review' "$TEAM"
}

@test "[#163] guard is non-vacuous: a command lacking the per-issue-verdict rule fails" {
  local f; f="$(mktemp)"
  printf '# a command with no per-issue verdict rule\n' > "$f"
  ! grep -qiF 'One issue, one invocation, one verdict' "$f"
  rm -f "$f"
}

@test "[#173] linux-admin has no user-confirmation spawn gate (#116/#159 autonomy)" {
  local hits bad
  hits="$(grep -niE 'wait([[:alpha:]]*)? for (the )?user (confirmation|approval)' "$LINUX_ADMIN" || true)"
  bad="$(printf '%s\n' "$hits" | grep -viE '(never|not|don.t|without)[[:space:]].*wait([[:alpha:]]*)? for (the )?user (confirmation|approval)' || true)"
  if [ -n "$bad" ]; then echo "spawn-gate wait-for-user-confirmation survives in linux-admin:" >&2; echo "$bad" >&2; return 1; fi
  ! grep -qiF 'WAIT for user confirmation before spawning' "$LINUX_ADMIN"
}

@test "[#173] linux-admin KEEPS the destructive-op confirmation gate (:133 legit)" {
  grep -qiF 'explicit user confirmation' "$LINUX_ADMIN"
  grep -qiE 'SSH access|service downtime|data loss|network partition' "$LINUX_ADMIN"
}

@test "[#173] guard bites: a spawn-confirmation gate is flagged" {
  local f; f="$(mktemp)"
  printf 'WAIT for user confirmation before spawning teammates.\n' > "$f"
  grep -qiF 'WAIT for user confirmation before spawning' "$f"
  rm -f "$f"
}
