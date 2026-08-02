#!/usr/bin/env bats
# #109 shell-broker: teammates are shell-less proposal-only; the Team Lead is the
# sole executor. Guards the invariant + bites on a reintroduced teammate-execute path.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SKILL="${REPO_ROOT}/my/skills/c-bpm-sk-linux-admin/SKILL.md"
ADMIN="${REPO_ROOT}/my/skills/c-bpm-sk-linux-admin/references/admin-instructions.md"
EXEC='(run|runs|execute|executes|implement|implements|apply|applies|validate|validates|verify|verifies|rollback|roll back|restart|restarts|modify|modifies|remove|removes|install|installs|sudo)'

@test "[#109] positive invariant: shell-less teammates + Lead sole executor are asserted" {
  grep -qiF 'sole executor of Phase 0 bootstrap and all' "$SKILL"
  grep -qiF 'Teammates do NOT have shell access and must NEVER run commands themselves' "$SKILL"
  grep -qiF 'You do NOT have shell access' "$ADMIN"
  grep -qiF 'You NEVER execute commands' "$ADMIN"
}

@test "[#109] SKILL.md: no un-negated third-person teammate-execute survives" {
  run bash -c "grep -inE '\\b(admin )?teammate(s)?\\b[^.]*\\b${EXEC}\\b' '$SKILL' | grep -viE 'do (NOT|not)|NEVER|never|no shell|without shell|propose|proposes|does not|shell-less|Team Lead-scoped'"
  [ "$status" -ne 0 ]  # grep -v finds nothing -> no survivor
}

@test "[#109] admin-instructions.md: no un-negated second-person teammate-execute survives" {
  run bash -c "grep -inE '\\b[Yy]ou\\b[^.]*\\b${EXEC}\\b' '$ADMIN' | grep -viE 'do (NOT|not)|NEVER|never|Team Lead|for Team Lead|propose|proposes|recommend|interpret|instruct|stay available|no shell'"
  [ "$status" -ne 0 ]
}

@test "[#109] no anti-broker wording denies Lead execution" {
  ! grep -qiE 'do NOT run fix commands|coordinates but NEVER implements|except Phase 0 bootstrap and read-only verification' "$SKILL" "$ADMIN"
}

@test "[#109] guard bites: a reintroduced teammate-execute line is caught" {
  local f; f="$(mktemp)"
  printf 'You run the fix commands in order.\n' > "$f"
  run bash -c "grep -inE '\\b[Yy]ou\\b[^.]*\\b${EXEC}\\b' '$f' | grep -viE 'do (NOT|not)|NEVER|Team Lead|propose'"
  rm -f "$f"
  [ "$status" -eq 0 ]  # the violating line IS found -> guard bites
}
