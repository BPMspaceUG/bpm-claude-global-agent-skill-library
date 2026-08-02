#!/usr/bin/env bats
#
# c-bpm-cm-openissues-list.bats — guards for the open-issues dashboard command
# (Issue #149: test-approved / DONE / CANCELLED rows are hidden from the table).
#
# Assertions run on the command-authored region only; the stamped issue-comms
# block is stripped (byte identity owned by issue-comms-anchor.bats).

set -u

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
CMD="${REPO_ROOT}/my/commands/c-bpm-cm-openissues-list.md"

authored() {
  awk '
    /<!-- BEGIN issue-comms/ { p=1 }
    !p { print }
    /<!-- END issue-comms/   { p=0 }
  ' "${CMD}"
}

@test "command file exists" {
  [ -f "${CMD}" ]
}

@test "#149/1: display rule hides test-approved, DONE and CANCELLED rows" {
  local body
  body="$(authored)"
  echo "${body}" | grep -qiE 'not (rendered|displayed|shown)|never (rendered|displayed|shown)|hidden from the table'
  # All three states named on the display-rule line(s).
  echo "${body}" | grep -E 'test-approved.*DONE.*CANCELLED|`test-approved`' | grep -qiE 'table|render|display|show'
}

@test "#149/2: summary still reports the three #148 counts plus the total" {
  local body
  body="$(authored)"
  echo "${body}" | grep -qF 'open (actionable'
  echo "${body}" | grep -qF 'test-approved (waiting for human DONE sign-off)'
  echo "${body}" | grep -qF 'CANCELLED (terminal)'
  echo "${body}" | grep -qF 'GitHub-open issue(s) total'
}

@test "#149/3: issues without milestone still render in the table" {
  authored | grep -qiE '(without|no) milestone.*(still|always).*(render|displayed|shown|appear)|(render|displayed|shown|appear).*(without|no) milestone'
}

@test "#149/4: stamped issue-comms markers intact" {
  grep -qF '<!-- BEGIN issue-comms' "${CMD}"
  grep -qF '<!-- END issue-comms' "${CMD}"
}

@test "[#127] openissues-list carries the evidence-re-verify step for implemented+ issues" {
  grep -qiF 'Evidence re-verify' "$CMD"
  grep -qiF 'MILESTONE-UNBACKED' "$CMD"
  grep -qiF 'implemented' "$CMD"
  grep -qiF 'does not resolve' "$CMD"
}

@test "[#127] openissues-list states milestones follow commits, not narratives" {
  grep -qiF 'milestones follow commits, not narratives' "$CMD"
}

@test "[#127] guard is non-vacuous: a command lacking the re-verify step fails" {
  local f; f="$(mktemp)"
  printf '# a dashboard with no evidence re-verify\n' > "$f"
  ! grep -qiF 'MILESTONE-UNBACKED' "$f"
  rm -f "$f"
}

@test "[#174] openissues-list references c-bpm-sk-milestone-type as the lifecycle source" {
  grep -qF 'c-bpm-sk-milestone-type' "$CMD"
  grep -qiF 'Do not copy the lifecycle' "$CMD"
}

@test "[#174] openissues-list no longer embeds the copied lifecycle block" {
  ! grep -qiF '### Non-Negotiable Rules' "$CMD"
  ! grep -qiF 'Dual approval required' "$CMD"
  ! grep -qiF '## Mandatory: Milestone-Based Issue Lifecycle' "$CMD"
}

@test "[#174] the lifecycle pointer is resolvable, not a dangling reference" {
  grep -qF 'my/skills/c-bpm-sk-milestone-type/SKILL.md' "$CMD"
  grep -qF '~/.claude/skills/c-bpm-sk-milestone-type/SKILL.md' "$CMD"
  grep -qF 'github.com/BPMspaceUG/bpm-claude-global-agent-skill-library' "$CMD"
  grep -qF 'target="_blank"' "$CMD"
}
