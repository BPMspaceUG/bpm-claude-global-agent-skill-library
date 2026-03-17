#!/usr/bin/env bats
#
# sync-dedup.bats - Tests for Issues #7 and #15
#   #7:  ORG_PREFIX filtering in pull/push glob patterns
#   #15: Shared sync functions extracted to lib.sh
#
# Run with: bats tests/bash/sync-dedup.bats

REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
LIB_SH="${REPO_ROOT}/lib.sh"
PULL="${REPO_ROOT}/my-bpm-library-pull"
PUSH="${REPO_ROOT}/my-bpm-library-push"

# ============================================================================
# Syntax checks
# ============================================================================

@test "bash -n lib.sh passes" {
  run bash -n "$LIB_SH"
  [ "$status" -eq 0 ]
}

@test "bash -n my-bpm-library-pull passes" {
  run bash -n "$PULL"
  [ "$status" -eq 0 ]
}

@test "bash -n my-bpm-library-push passes" {
  run bash -n "$PUSH"
  [ "$status" -eq 0 ]
}

# ============================================================================
# Issue #15: Shared functions in lib.sh
# ============================================================================

@test "lib.sh contains compute_item_hash" {
  run grep -c '^compute_item_hash()' "$LIB_SH"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "lib.sh contains load_sync_state" {
  run grep -c '^load_sync_state()' "$LIB_SH"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "lib.sh contains save_sync_state" {
  run grep -c '^save_sync_state()' "$LIB_SH"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "lib.sh contains get_sync_hash" {
  run grep -c '^get_sync_hash()' "$LIB_SH"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "lib.sh contains set_sync_hash" {
  run grep -c '^set_sync_hash()' "$LIB_SH"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "lib.sh contains prune_sync_state" {
  run grep -c '^prune_sync_state()' "$LIB_SH"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "lib.sh declares SYNC_STATE associative array" {
  run grep -c 'declare -A SYNC_STATE' "$LIB_SH"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# ============================================================================
# Issue #15: Duplicate functions removed from pull/push
# ============================================================================

@test "pull does NOT define compute_item_hash locally" {
  run grep -c '^compute_item_hash()' "$PULL"
  [ "$output" = "0" ]
}

@test "pull does NOT define load_sync_state locally" {
  run grep -c '^load_sync_state()' "$PULL"
  [ "$output" = "0" ]
}

@test "pull does NOT define save_sync_state locally" {
  run grep -c '^save_sync_state()' "$PULL"
  [ "$output" = "0" ]
}

@test "pull does NOT define get_sync_hash locally" {
  run grep -c '^get_sync_hash()' "$PULL"
  [ "$output" = "0" ]
}

@test "pull does NOT define set_sync_hash locally" {
  run grep -c '^set_sync_hash()' "$PULL"
  [ "$output" = "0" ]
}

@test "pull does NOT define prune_sync_state locally" {
  run grep -c '^prune_sync_state()' "$PULL"
  [ "$output" = "0" ]
}

@test "pull does NOT define log_verbose locally" {
  run grep -c '^log_verbose()' "$PULL"
  [ "$output" = "0" ]
}

@test "pull does NOT define get_target_dir locally" {
  run grep -c '^get_target_dir()' "$PULL"
  [ "$output" = "0" ]
}

@test "push does NOT define compute_item_hash locally" {
  run grep -c '^compute_item_hash()' "$PUSH"
  [ "$output" = "0" ]
}

@test "push does NOT define load_sync_state locally" {
  run grep -c '^load_sync_state()' "$PUSH"
  [ "$output" = "0" ]
}

@test "push does NOT define save_sync_state locally" {
  run grep -c '^save_sync_state()' "$PUSH"
  [ "$output" = "0" ]
}

@test "push does NOT define log_verbose locally" {
  run grep -c '^log_verbose()' "$PUSH"
  [ "$output" = "0" ]
}

@test "push does NOT define get_source_dir locally" {
  run grep -c '^get_source_dir()' "$PUSH"
  [ "$output" = "0" ]
}

# ============================================================================
# Issue #15: lib.sh sourced early (before show_help)
# ============================================================================

@test "pull sources lib.sh before show_help" {
  source_line=$(grep -n 'source.*lib\.sh' "$PULL" | head -1 | cut -d: -f1)
  help_line=$(grep -n '^show_help()' "$PULL" | head -1 | cut -d: -f1)
  [ -n "$source_line" ]
  [ -n "$help_line" ]
  [ "$source_line" -lt "$help_line" ]
}

@test "push sources lib.sh before show_help" {
  source_line=$(grep -n 'source.*lib\.sh' "$PUSH" | head -1 | cut -d: -f1)
  help_line=$(grep -n '^show_help()' "$PUSH" | head -1 | cut -d: -f1)
  [ -n "$source_line" ]
  [ -n "$help_line" ]
  [ "$source_line" -lt "$help_line" ]
}

@test "pull does NOT have a late source lib.sh (only one source line)" {
  run grep -c 'source.*lib\.sh' "$PULL"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "push does NOT have a late source lib.sh (only one source line)" {
  run grep -c 'source.*lib\.sh' "$PUSH"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# ============================================================================
# Issue #7: ORG_PREFIX filtering in glob patterns
# ============================================================================

@test "pull uses ORG_PREFIX in skills glob (not bare my-*/)" {
  # Should NOT match: my-*/
  # Should match: my-"${ORG_PREFIX}"-*/
  run grep -c '"$REPO_CAT_DIR"/my-\*/' "$PULL"
  [ "$output" = "0" ]
  run grep -c '"$LOCAL_CAT_DIR"/my-\*/' "$PULL"
  [ "$output" = "0" ]
}

@test "pull uses ORG_PREFIX in agents/commands/runbooks glob (not bare my-*.md)" {
  run grep -c '"$REPO_CAT_DIR"/my-\*\.md' "$PULL"
  [ "$output" = "0" ]
  run grep -c '"$LOCAL_CAT_DIR"/my-\*\.md' "$PULL"
  [ "$output" = "0" ]
}

@test "push uses ORG_PREFIX in skills glob (not bare my-*/)" {
  run grep -c '"$LOCAL_CAT_DIR"/my-\*/' "$PUSH"
  [ "$output" = "0" ]
  run grep -c '"$REPO_CAT_DIR"/my-\*/' "$PUSH"
  [ "$output" = "0" ]
}

@test "push uses ORG_PREFIX in agents/commands/runbooks glob (not bare my-*.md)" {
  run grep -c '"$LOCAL_CAT_DIR"/my-\*\.md' "$PUSH"
  [ "$output" = "0" ]
  run grep -c '"$REPO_CAT_DIR"/my-\*\.md' "$PUSH"
  [ "$output" = "0" ]
}

@test "pull glob patterns reference ORG_PREFIX variable" {
  # All glob for-loops should contain ORG_PREFIX
  count=$(grep -c 'ORG_PREFIX' "$PULL")
  [ "$count" -ge 4 ]
}

@test "push glob patterns reference ORG_PREFIX variable" {
  count=$(grep -c 'ORG_PREFIX' "$PUSH")
  [ "$count" -ge 4 ]
}

# ============================================================================
# Version bump
# ============================================================================

@test "pull version is 1.3.0" {
  run grep '^VERSION="1.3.0"' "$PULL"
  [ "$status" -eq 0 ]
}

@test "push version is 1.3.0" {
  run grep '^VERSION="1.3.0"' "$PUSH"
  [ "$status" -eq 0 ]
}

# ============================================================================
# Functional: lib.sh functions work correctly
# ============================================================================

@test "compute_item_hash produces consistent hash for a file" {
  tmp=$(mktemp)
  echo "test content" > "$tmp"
  source "$LIB_SH"
  hash1=$(compute_item_hash "$tmp")
  hash2=$(compute_item_hash "$tmp")
  [ -n "$hash1" ]
  [ "$hash1" = "$hash2" ]
  rm -f "$tmp"
}

@test "compute_item_hash returns empty for non-existent path" {
  source "$LIB_SH"
  hash=$(compute_item_hash "/nonexistent/path/12345")
  [ -z "$hash" ]
}

@test "get/set_sync_hash roundtrip" {
  source "$LIB_SH"
  SYNC_STATE=()
  set_sync_hash "skills/my-bpm-test" "abc123"
  result=$(get_sync_hash "skills/my-bpm-test")
  [ "$result" = "abc123" ]
}

@test "get_sync_hash returns empty for unknown key" {
  source "$LIB_SH"
  SYNC_STATE=()
  result=$(get_sync_hash "nonexistent/key")
  [ -z "$result" ]
}

@test "load_sync_state and save_sync_state roundtrip" {
  source "$LIB_SH"
  SYNC_STATE=()
  DRY_RUN=0
  VERBOSE=0
  tmp=$(mktemp)

  set_sync_hash "skills/my-bpm-a" "hash_a"
  set_sync_hash "agents/my-bpm-b.md" "hash_b"
  save_sync_state "$tmp"

  # Reset and reload
  SYNC_STATE=()
  load_sync_state "$tmp"

  [ "$(get_sync_hash 'skills/my-bpm-a')" = "hash_a" ]
  [ "$(get_sync_hash 'agents/my-bpm-b.md')" = "hash_b" ]
  rm -f "$tmp"
}

@test "save_sync_state skips when DRY_RUN=1" {
  source "$LIB_SH"
  SYNC_STATE=()
  DRY_RUN=1
  VERBOSE=0
  tmp=$(mktemp)

  set_sync_hash "skills/my-bpm-test" "hash123"
  save_sync_state "$tmp"

  # File should be empty (nothing written)
  [ ! -s "$tmp" ]
  rm -f "$tmp"
}

@test "ORG_PREFIX is set to bpm in lib.sh" {
  source "$LIB_SH"
  [ "$ORG_PREFIX" = "bpm" ]
}
