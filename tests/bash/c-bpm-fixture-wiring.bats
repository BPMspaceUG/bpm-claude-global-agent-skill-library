#!/usr/bin/env bats
# #161 — every fixture id in a fixtures.json must be wired to an EXECUTABLE
# `run_fixture <id>` call in its bats suite. A token in a comment, a string, or a
# skip-guarded @test does NOT count — that is the "silently dead coverage" the
# guard exists to catch.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
IWG_JSON="${REPO_ROOT}/my/hooks/__tests__/issue-write-gate.fixtures.json"
IWG_BATS="${REPO_ROOT}/tests/bash/c-bpm-sk-issue-write-gate.bats"
PDG_JSON="${REPO_ROOT}/my/hooks/__tests__/plan-doc-gate.fixtures.json"
PDG_BATS="${REPO_ROOT}/tests/bash/c-bpm-sk-plan-doc-gate.bats"

# Print the fixture ids that are exercised: run_fixture calls at COMMAND POSITION
# (line start after optional whitespace — excludes `# run_fixture`, `echo "run_fixture"`,
# heredoc/string tokens) inside a @test block that does NOT call `skip`.
_wired_ids() {
  awk '
    /^[[:space:]]*@test/      { inblk=1; skipped=0; n=0; delete a; next }
    inblk && /^[[:space:]]*skip([[:space:]]|$)/ { skipped=1 }
    inblk && /^[[:space:]]*run_fixture[[:space:]]+[0-9]+([^0-9]|$)/ {
      s=$0; sub(/^[[:space:]]*run_fixture[[:space:]]+/,"",s); sub(/[^0-9].*$/,"",s); a[n++]=s
    }
    inblk && /^}/ { if(!skipped){ for(i=0;i<n;i++) print a[i] } inblk=0 }
  ' "$1" | sort -u
}

# Print fixture ids from the json that are NOT exercised. Also flags a non-numeric id.
_unwired_ids() {
  local json="$1" bats="$2" id wired
  wired="$(_wired_ids "$bats")"
  while read -r id; do
    [ -n "$id" ] || continue
    case "$id" in *[!0-9]*) printf 'NON_NUMERIC:%s ' "$id"; continue ;; esac
    printf '%s\n' "$wired" | grep -qxF "$id" || printf '%s ' "$id"
  done < <(jq -r '.fixtures[].id' "$json")
}

@test "[#161] every issue-write-gate fixture id is wired to an executable run_fixture call" {
  local missing; missing="$(_unwired_ids "$IWG_JSON" "$IWG_BATS")"
  if [ -n "$missing" ]; then echo "unwired issue-write-gate fixture ids: $missing" >&2; return 1; fi
}

@test "[#161] every plan-doc-gate fixture id is wired to an executable run_fixture call" {
  local missing; missing="$(_unwired_ids "$PDG_JSON" "$PDG_BATS")"
  if [ -n "$missing" ]; then echo "unwired plan-doc-gate fixture ids: $missing" >&2; return 1; fi
}

@test "[#161] bites: an id with no run_fixture call is reported" {
  local d; d="$(mktemp -d)"
  printf '{"fixtures":[{"id":999}]}' > "$d/f.json"
  printf '@test "x" {\n  run_fixture 1\n}\n' > "$d/s.bats"
  local m; m="$(_unwired_ids "$d/f.json" "$d/s.bats")"; rm -rf "$d"
  [[ "$m" == *999* ]]
}

@test "[#161] word-boundary: run_fixture 11 does not satisfy id 1" {
  local d; d="$(mktemp -d)"
  printf '{"fixtures":[{"id":1}]}' > "$d/f.json"
  printf '@test "x" {\n  run_fixture 11\n}\n' > "$d/s.bats"
  local m; m="$(_unwired_ids "$d/f.json" "$d/s.bats")"; rm -rf "$d"
  [[ "$m" == *1* ]]
}

@test "[#161] comment hole closed: a commented run_fixture does NOT count as wired" {
  local d; d="$(mktemp -d)"
  printf '{"fixtures":[{"id":5}]}' > "$d/f.json"
  printf '@test "x" {\n  # run_fixture 5\n  echo "run_fixture 5"\n}\n' > "$d/s.bats"
  local m; m="$(_unwired_ids "$d/f.json" "$d/s.bats")"; rm -rf "$d"
  [[ "$m" == *5* ]]
}

@test "[#161] skip hole closed: a run_fixture in a skip-guarded @test does NOT count" {
  local d; d="$(mktemp -d)"
  printf '{"fixtures":[{"id":7}]}' > "$d/f.json"
  printf '@test "x" {\n  skip "not in ci"\n  run_fixture 7\n}\n' > "$d/s.bats"
  local m; m="$(_unwired_ids "$d/f.json" "$d/s.bats")"; rm -rf "$d"
  [[ "$m" == *7* ]]
}
