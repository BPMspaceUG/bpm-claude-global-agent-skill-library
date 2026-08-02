#!/usr/bin/env bats
# #166 — repo confinement is stated authoritatively (CLAUDE.md) and injected live
# (SessionStart hook); the two must not drift apart.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
CLAUDEMD="${REPO_ROOT}/CLAUDE.md"
TRACKER="${REPO_ROOT}/my/hooks/codex-sod-tracker.sh"

@test "[#166] CLAUDE.md states the repo-confinement rule with both permitted cross-repo actions" {
  grep -qF 'Repository Confinement' "$CLAUDEMD"
  grep -qiF 'only within the repositor' "$CLAUDEMD"
  grep -qiF 'installed central' "$CLAUDEMD"
  grep -qiF 'Create a new Issue' "$CLAUDEMD"
  grep -qiF 'Comment on an Issue' "$CLAUDEMD"
  grep -qiF 'this same session created' "$CLAUDEMD"
}

@test "[#166] the SessionStart hook injects the REPO CONFINEMENT rule (doc/enforcement no-drift)" {
  local out
  out="$(echo '{"session_id":"t166guard"}' | bash "$TRACKER" SESSION_START)"
  echo "$out" | grep -qF 'REPO CONFINEMENT'
  echo "$out" | grep -qiF 'creating an Issue in another repo'
  echo "$out" | grep -qiF 'commenting on an Issue this session created'
  rm -rf /tmp/claude-codex-sod/t166guard
}

@test "[#166] guard is non-vacuous: a doc without the permitted-actions clause fails" {
  local f; f="$(mktemp)"
  printf '# Some doc\nWork only in this repo.\n' > "$f"
  ! grep -qiF 'Comment on an Issue' "$f"
  rm -f "$f"
}
