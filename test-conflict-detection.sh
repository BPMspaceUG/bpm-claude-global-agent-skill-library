#!/usr/bin/env bash
#
# test-conflict-detection.sh - Test all conflict detection scenarios
#
# Creates isolated test environment, simulates all pull/push cases,
# verifies correct behavior. Does NOT touch real ~/.claude/ or the real repo.
#
# Usage: ./test-conflict-detection.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# Test result helper
assert() {
  local description="$1"
  local condition="$2"
  ((TOTAL_COUNT++)) || true

  if eval "$condition"; then
    echo -e "  ${GREEN}PASS${NC} $description"
    ((PASS_COUNT++)) || true
  else
    echo -e "  ${RED}FAIL${NC} $description"
    ((FAIL_COUNT++)) || true
  fi
}

assert_contains() {
  local description="$1"
  local haystack="$2"
  local needle="$3"
  ((TOTAL_COUNT++)) || true

  if echo "$haystack" | grep -q "$needle"; then
    echo -e "  ${GREEN}PASS${NC} $description"
    ((PASS_COUNT++)) || true
  else
    echo -e "  ${RED}FAIL${NC} $description — expected to find: $needle"
    ((FAIL_COUNT++)) || true
  fi
}

assert_not_contains() {
  local description="$1"
  local haystack="$2"
  local needle="$3"
  ((TOTAL_COUNT++)) || true

  if ! echo "$haystack" | grep -q "$needle"; then
    echo -e "  ${GREEN}PASS${NC} $description"
    ((PASS_COUNT++)) || true
  else
    echo -e "  ${RED}FAIL${NC} $description — should NOT contain: $needle"
    ((FAIL_COUNT++)) || true
  fi
}

assert_file_content() {
  local description="$1"
  local file="$2"
  local expected="$3"
  ((TOTAL_COUNT++)) || true

  if [[ -f "$file" ]] && [[ "$(cat "$file")" == "$expected" ]]; then
    echo -e "  ${GREEN}PASS${NC} $description"
    ((PASS_COUNT++)) || true
  else
    local actual=""
    [[ -f "$file" ]] && actual="$(cat "$file")"
    echo -e "  ${RED}FAIL${NC} $description — expected: '$expected', got: '$actual'"
    ((FAIL_COUNT++)) || true
  fi
}

# --- Setup isolated test environment ---

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

FAKE_HOME="$TEST_DIR/home"
FAKE_CLAUDE="$FAKE_HOME/.claude"
FAKE_REPO="$FAKE_HOME/bpm-claude-global-agent-skill-library"

setup_environment() {
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR"
  mkdir -p "$FAKE_CLAUDE"
  mkdir -p "$FAKE_REPO/.git"  # Fake git dir so scripts think repo exists
  mkdir -p "$FAKE_REPO/my/skills"
  mkdir -p "$FAKE_REPO/my/agents"
  mkdir -p "$FAKE_REPO/my/commands"
  mkdir -p "$FAKE_REPO/my/runbooks"
  mkdir -p "$FAKE_CLAUDE/skills"
  mkdir -p "$FAKE_CLAUDE/agents"
  mkdir -p "$FAKE_CLAUDE/commands"
  mkdir -p "$FAKE_CLAUDE/runbooks"

  # Create fake settings.json so get_target_dir picks ~/.claude
  echo '{}' > "$FAKE_CLAUDE/settings.json"
}

# Create a modified version of pull/push that works with fake paths
# We override HOME and disable git operations
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

create_test_pull() {
  cat > "$TEST_DIR/test-pull" <<'PULLEOF'
#!/usr/bin/env bash
set -euo pipefail

# Injected by test harness
HOME="__FAKE_HOME__"
VERSION="1.1.0-test"
REPO_NAME="bpm-claude-global-agent-skill-library"
REPO_DIR="$HOME/$REPO_NAME"

DRY_RUN=0
VERBOSE=0
FORCE=0
ONLY_SKILLS=0
ONLY_AGENTS=0
ONLY_COMMANDS=0
ONLY_RUNBOOKS=0
CATEGORIES=(skills agents commands runbooks)

get_target_dir() {
  if [[ -f "$HOME/.claude/settings.json" ]]; then
    echo "$HOME/.claude"
  elif [[ -f "$HOME/.config/claude/settings.json" ]]; then
    echo "$HOME/.config/claude"
  else
    echo "$HOME/.claude"
  fi
}

log_verbose() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

declare -A SYNC_STATE

compute_item_hash() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" && find . -type f -print0 | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)
  elif [[ -f "$path" ]]; then
    sha256sum "$path" | cut -d' ' -f1
  else
    echo ""
  fi
}

load_sync_state() {
  local sync_file="$1"
  SYNC_STATE=()
  [[ -f "$sync_file" ]] || return 0
  while IFS=' ' read -r hash key; do
    [[ -z "$hash" || "$hash" == "#"* ]] && continue
    SYNC_STATE["$key"]="$hash"
  done < "$sync_file"
}

get_sync_hash() { echo "${SYNC_STATE[$1]:-}"; }
set_sync_hash() { SYNC_STATE["$1"]="$2"; }

save_sync_state() {
  local sync_file="$1"
  [[ "$DRY_RUN" -eq 1 ]] && return 0
  : > "$sync_file"
  for key in $(echo "${!SYNC_STATE[@]}" | tr ' ' '\n' | sort); do
    echo "${SYNC_STATE[$key]} $key" >> "$sync_file"
  done
}

# Parse args
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --verbose) VERBOSE=1 ;;
    --force)   FORCE=1 ;;
    --only-skills) ONLY_SKILLS=1 ;;
    --only-agents) ONLY_AGENTS=1 ;;
    --only-commands) ONLY_COMMANDS=1 ;;
    --only-runbooks) ONLY_RUNBOOKS=1 ;;
  esac
done

if [[ "$ONLY_SKILLS" -eq 1 ]] || [[ "$ONLY_AGENTS" -eq 1 ]] || [[ "$ONLY_COMMANDS" -eq 1 ]] || [[ "$ONLY_RUNBOOKS" -eq 1 ]]; then
  CATEGORIES=()
  [[ "$ONLY_SKILLS" -eq 1 ]] && CATEGORIES+=("skills")
  [[ "$ONLY_AGENTS" -eq 1 ]] && CATEGORIES+=("agents")
  [[ "$ONLY_COMMANDS" -eq 1 ]] && CATEGORIES+=("commands")
  [[ "$ONLY_RUNBOOKS" -eq 1 ]] && CATEGORIES+=("runbooks")
fi

TARGET_DIR="$(get_target_dir)"
SYNC_STATE_FILE="$TARGET_DIR/.my-bpm-library-sync"
load_sync_state "$SYNC_STATE_FILE"

# Skip git operations (no real repo)

NEW_COUNT=0
MODIFIED_COUNT=0
UNCHANGED_COUNT=0
CONFLICT_COUNT=0

for category in "${CATEGORIES[@]}"; do
  REPO_CAT_DIR="$REPO_DIR/my/$category"
  [[ -d "$REPO_CAT_DIR" ]] || continue
  LOCAL_CAT_DIR="$TARGET_DIR/$category"
  mkdir -p "$LOCAL_CAT_DIR"

  if [[ "$category" == "skills" ]]; then
    for item_dir in "$REPO_CAT_DIR"/my-*/; do
      [[ -d "$item_dir" ]] || continue
      item_name=$(basename "$item_dir")
      local_item="$LOCAL_CAT_DIR/$item_name"
      item_key="$category/$item_name"

      if [[ ! -d "$local_item" ]]; then
        echo "  + $item_key (new)"
        ((NEW_COUNT++)) || true
        if [[ "$DRY_RUN" -eq 0 ]]; then
          cp -r "$item_dir" "$local_item"
          set_sync_hash "$item_key" "$(compute_item_hash "$local_item")"
        fi
      elif ! diff -rq "$item_dir" "$local_item" > /dev/null 2>&1; then
        baseline_hash=$(get_sync_hash "$item_key")
        if [[ -n "$baseline_hash" ]]; then
          local_hash=$(compute_item_hash "$local_item")
          repo_hash=$(compute_item_hash "$item_dir")
          local_changed=0; repo_changed=0
          [[ "$local_hash" != "$baseline_hash" ]] && local_changed=1
          [[ "$repo_hash" != "$baseline_hash" ]] && repo_changed=1
          if [[ "$local_changed" -eq 1 ]] && [[ "$repo_changed" -eq 1 ]]; then
            if [[ "$FORCE" -eq 1 ]]; then
              echo "  ~ $item_key (CONFLICT resolved: --force, repo wins)"
              ((MODIFIED_COUNT++)) || true
              if [[ "$DRY_RUN" -eq 0 ]]; then
                rm -rf "$local_item"; cp -r "$item_dir" "$local_item"
                set_sync_hash "$item_key" "$(compute_item_hash "$local_item")"
              fi
            else
              echo "  X $item_key (CONFLICT: changed locally AND in repo)"
              ((CONFLICT_COUNT++)) || true
            fi
            continue
          fi
        fi
        echo "  ~ $item_key (modified)"
        ((MODIFIED_COUNT++)) || true
        if [[ "$DRY_RUN" -eq 0 ]]; then
          rm -rf "$local_item"; cp -r "$item_dir" "$local_item"
          set_sync_hash "$item_key" "$(compute_item_hash "$local_item")"
        fi
      else
        ((UNCHANGED_COUNT++)) || true
        if [[ -z "$(get_sync_hash "$item_key")" ]] && [[ "$DRY_RUN" -eq 0 ]]; then
          set_sync_hash "$item_key" "$(compute_item_hash "$local_item")"
        fi
      fi
    done
  else
    for item_file in "$REPO_CAT_DIR"/my-*.md; do
      [[ -f "$item_file" ]] || continue
      item_name=$(basename "$item_file")
      local_item="$LOCAL_CAT_DIR/$item_name"
      item_key="$category/$item_name"

      if [[ ! -f "$local_item" ]]; then
        echo "  + $item_key (new)"
        ((NEW_COUNT++)) || true
        if [[ "$DRY_RUN" -eq 0 ]]; then
          cp "$item_file" "$local_item"
          set_sync_hash "$item_key" "$(compute_item_hash "$local_item")"
        fi
      elif ! diff -q "$item_file" "$local_item" > /dev/null 2>&1; then
        baseline_hash=$(get_sync_hash "$item_key")
        if [[ -n "$baseline_hash" ]]; then
          local_hash=$(compute_item_hash "$local_item")
          repo_hash=$(compute_item_hash "$item_file")
          local_changed=0; repo_changed=0
          [[ "$local_hash" != "$baseline_hash" ]] && local_changed=1
          [[ "$repo_hash" != "$baseline_hash" ]] && repo_changed=1
          if [[ "$local_changed" -eq 1 ]] && [[ "$repo_changed" -eq 1 ]]; then
            if [[ "$FORCE" -eq 1 ]]; then
              echo "  ~ $item_key (CONFLICT resolved: --force, repo wins)"
              ((MODIFIED_COUNT++)) || true
              if [[ "$DRY_RUN" -eq 0 ]]; then
                cp "$item_file" "$local_item"
                set_sync_hash "$item_key" "$(compute_item_hash "$local_item")"
              fi
            else
              echo "  X $item_key (CONFLICT: changed locally AND in repo)"
              ((CONFLICT_COUNT++)) || true
            fi
            continue
          fi
        fi
        echo "  ~ $item_key (modified)"
        ((MODIFIED_COUNT++)) || true
        if [[ "$DRY_RUN" -eq 0 ]]; then
          cp "$item_file" "$local_item"
          set_sync_hash "$item_key" "$(compute_item_hash "$local_item")"
        fi
      else
        ((UNCHANGED_COUNT++)) || true
        if [[ -z "$(get_sync_hash "$item_key")" ]] && [[ "$DRY_RUN" -eq 0 ]]; then
          set_sync_hash "$item_key" "$(compute_item_hash "$local_item")"
        fi
      fi
    done
  fi
done

save_sync_state "$SYNC_STATE_FILE"

echo ""
echo "new=$NEW_COUNT modified=$MODIFIED_COUNT unchanged=$UNCHANGED_COUNT conflicts=$CONFLICT_COUNT"
if [[ "$CONFLICT_COUNT" -gt 0 ]]; then
  echo "CONFLICTS: $CONFLICT_COUNT item(s) changed on both sides."
fi
PULLEOF

  sed -i "s|__FAKE_HOME__|$FAKE_HOME|g" "$TEST_DIR/test-pull"
  chmod +x "$TEST_DIR/test-pull"
}

create_test_push() {
  cat > "$TEST_DIR/test-push" <<'PUSHEOF'
#!/usr/bin/env bash
set -euo pipefail

HOME="__FAKE_HOME__"
VERSION="1.1.0-test"
REPO_NAME="bpm-claude-global-agent-skill-library"
REPO_DIR="$HOME/$REPO_NAME"

DRY_RUN=0
VERBOSE=0
FORCE=0
ONLY_SKILLS=0
ONLY_AGENTS=0
ONLY_COMMANDS=0
ONLY_RUNBOOKS=0
CATEGORIES=(skills agents commands runbooks)

get_source_dir() {
  if [[ -f "$HOME/.claude/settings.json" ]]; then
    echo "$HOME/.claude"
  elif [[ -f "$HOME/.config/claude/settings.json" ]]; then
    echo "$HOME/.config/claude"
  else
    echo "$HOME/.claude"
  fi
}

log_verbose() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

declare -A SYNC_STATE

compute_item_hash() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" && find . -type f -print0 | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1)
  elif [[ -f "$path" ]]; then
    sha256sum "$path" | cut -d' ' -f1
  else
    echo ""
  fi
}

load_sync_state() {
  local sync_file="$1"
  SYNC_STATE=()
  [[ -f "$sync_file" ]] || return 0
  while IFS=' ' read -r hash key; do
    [[ -z "$hash" || "$hash" == "#"* ]] && continue
    SYNC_STATE["$key"]="$hash"
  done < "$sync_file"
}

get_sync_hash() { echo "${SYNC_STATE[$1]:-}"; }
set_sync_hash() { SYNC_STATE["$1"]="$2"; }

save_sync_state() {
  local sync_file="$1"
  [[ "$DRY_RUN" -eq 1 ]] && return 0
  : > "$sync_file"
  for key in $(echo "${!SYNC_STATE[@]}" | tr ' ' '\n' | sort); do
    echo "${SYNC_STATE[$key]} $key" >> "$sync_file"
  done
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --verbose) VERBOSE=1 ;;
    --force)   FORCE=1 ;;
    --only-skills) ONLY_SKILLS=1 ;;
    --only-agents) ONLY_AGENTS=1 ;;
    --only-commands) ONLY_COMMANDS=1 ;;
    --only-runbooks) ONLY_RUNBOOKS=1 ;;
  esac
done

if [[ "$ONLY_SKILLS" -eq 1 ]] || [[ "$ONLY_AGENTS" -eq 1 ]] || [[ "$ONLY_COMMANDS" -eq 1 ]] || [[ "$ONLY_RUNBOOKS" -eq 1 ]]; then
  CATEGORIES=()
  [[ "$ONLY_SKILLS" -eq 1 ]] && CATEGORIES+=("skills")
  [[ "$ONLY_AGENTS" -eq 1 ]] && CATEGORIES+=("agents")
  [[ "$ONLY_COMMANDS" -eq 1 ]] && CATEGORIES+=("commands")
  [[ "$ONLY_RUNBOOKS" -eq 1 ]] && CATEGORIES+=("runbooks")
fi

SOURCE_DIR="$(get_source_dir)"
SYNC_STATE_FILE="$SOURCE_DIR/.my-bpm-library-sync"
load_sync_state "$SYNC_STATE_FILE"

NEW_ITEMS=()
MODIFIED_ITEMS=()
DELETED_ITEMS=()
CONFLICT_ITEMS=()
UNCHANGED_COUNT=0

for category in "${CATEGORIES[@]}"; do
  LOCAL_CAT_DIR="$SOURCE_DIR/$category"
  REPO_CAT_DIR="$REPO_DIR/my/$category"
  [[ -d "$LOCAL_CAT_DIR" ]] || continue
  mkdir -p "$REPO_CAT_DIR"

  if [[ "$category" == "skills" ]]; then
    for item_dir in "$LOCAL_CAT_DIR"/my-*/; do
      [[ -d "$item_dir" ]] || continue
      item_name=$(basename "$item_dir")
      repo_item="$REPO_CAT_DIR/$item_name"
      item_key="$category/$item_name"

      if [[ ! -d "$repo_item" ]]; then
        echo "  + $item_key (new)"
        NEW_ITEMS+=("$item_key")
        if [[ "$DRY_RUN" -eq 0 ]]; then
          cp -r "$item_dir" "$repo_item"
          set_sync_hash "$item_key" "$(compute_item_hash "$item_dir")"
        fi
      elif ! diff -rq "$item_dir" "$repo_item" > /dev/null 2>&1; then
        baseline_hash=$(get_sync_hash "$item_key")
        if [[ -n "$baseline_hash" ]]; then
          local_hash=$(compute_item_hash "$item_dir")
          repo_hash=$(compute_item_hash "$repo_item")
          local_changed=0; repo_changed=0
          [[ "$local_hash" != "$baseline_hash" ]] && local_changed=1
          [[ "$repo_hash" != "$baseline_hash" ]] && repo_changed=1
          if [[ "$local_changed" -eq 1 ]] && [[ "$repo_changed" -eq 1 ]]; then
            if [[ "$FORCE" -eq 1 ]]; then
              echo "  ~ $item_key (CONFLICT resolved: --force, local wins)"
              MODIFIED_ITEMS+=("$item_key")
              if [[ "$DRY_RUN" -eq 0 ]]; then
                rm -rf "$repo_item"; cp -r "$item_dir" "$repo_item"
                set_sync_hash "$item_key" "$(compute_item_hash "$item_dir")"
              fi
            else
              echo "  X $item_key (CONFLICT: changed locally AND in repo)"
              CONFLICT_ITEMS+=("$item_key")
            fi
            continue
          fi
        fi
        echo "  ~ $item_key (modified)"
        MODIFIED_ITEMS+=("$item_key")
        if [[ "$DRY_RUN" -eq 0 ]]; then
          rm -rf "$repo_item"; cp -r "$item_dir" "$repo_item"
          set_sync_hash "$item_key" "$(compute_item_hash "$item_dir")"
        fi
      else
        ((UNCHANGED_COUNT++)) || true
        if [[ -z "$(get_sync_hash "$item_key")" ]] && [[ "$DRY_RUN" -eq 0 ]]; then
          set_sync_hash "$item_key" "$(compute_item_hash "$item_dir")"
        fi
      fi
    done

    for repo_item_dir in "$REPO_CAT_DIR"/my-*/; do
      [[ -d "$repo_item_dir" ]] || continue
      item_name=$(basename "$repo_item_dir")
      local_item="$LOCAL_CAT_DIR/$item_name"
      if [[ ! -d "$local_item" ]]; then
        echo "  ! $category/$item_name (in repo but not local - NOT auto-deleted)"
        DELETED_ITEMS+=("$category/$item_name")
      fi
    done
  else
    for item_file in "$LOCAL_CAT_DIR"/my-*.md; do
      [[ -f "$item_file" ]] || continue
      item_name=$(basename "$item_file")
      repo_item="$REPO_CAT_DIR/$item_name"
      item_key="$category/$item_name"

      if [[ ! -f "$repo_item" ]]; then
        echo "  + $item_key (new)"
        NEW_ITEMS+=("$item_key")
        if [[ "$DRY_RUN" -eq 0 ]]; then
          cp "$item_file" "$repo_item"
          set_sync_hash "$item_key" "$(compute_item_hash "$item_file")"
        fi
      elif ! diff -q "$item_file" "$repo_item" > /dev/null 2>&1; then
        baseline_hash=$(get_sync_hash "$item_key")
        if [[ -n "$baseline_hash" ]]; then
          local_hash=$(compute_item_hash "$item_file")
          repo_hash=$(compute_item_hash "$repo_item")
          local_changed=0; repo_changed=0
          [[ "$local_hash" != "$baseline_hash" ]] && local_changed=1
          [[ "$repo_hash" != "$baseline_hash" ]] && repo_changed=1
          if [[ "$local_changed" -eq 1 ]] && [[ "$repo_changed" -eq 1 ]]; then
            if [[ "$FORCE" -eq 1 ]]; then
              echo "  ~ $item_key (CONFLICT resolved: --force, local wins)"
              MODIFIED_ITEMS+=("$item_key")
              if [[ "$DRY_RUN" -eq 0 ]]; then
                cp "$item_file" "$repo_item"
                set_sync_hash "$item_key" "$(compute_item_hash "$item_file")"
              fi
            else
              echo "  X $item_key (CONFLICT: changed locally AND in repo)"
              CONFLICT_ITEMS+=("$item_key")
            fi
            continue
          fi
        fi
        echo "  ~ $item_key (modified)"
        MODIFIED_ITEMS+=("$item_key")
        if [[ "$DRY_RUN" -eq 0 ]]; then
          cp "$item_file" "$repo_item"
          set_sync_hash "$item_key" "$(compute_item_hash "$item_file")"
        fi
      else
        ((UNCHANGED_COUNT++)) || true
        if [[ -z "$(get_sync_hash "$item_key")" ]] && [[ "$DRY_RUN" -eq 0 ]]; then
          set_sync_hash "$item_key" "$(compute_item_hash "$item_file")"
        fi
      fi
    done

    for repo_item_file in "$REPO_CAT_DIR"/my-*.md; do
      [[ -f "$repo_item_file" ]] || continue
      item_name=$(basename "$repo_item_file")
      local_item="$LOCAL_CAT_DIR/$item_name"
      if [[ ! -f "$local_item" ]]; then
        echo "  ! $category/$item_name (in repo but not local - NOT auto-deleted)"
        DELETED_ITEMS+=("$category/$item_name")
      fi
    done
  fi
done

save_sync_state "$SYNC_STATE_FILE"

echo ""
echo "new=${#NEW_ITEMS[@]} modified=${#MODIFIED_ITEMS[@]} unchanged=$UNCHANGED_COUNT conflicts=${#CONFLICT_ITEMS[@]}"
if [[ ${#CONFLICT_ITEMS[@]} -gt 0 ]]; then
  echo "CONFLICTS: ${#CONFLICT_ITEMS[@]} item(s) changed on both sides."
fi
if [[ ${#DELETED_ITEMS[@]} -gt 0 ]]; then
  echo "DELETED_WARNINGS: ${#DELETED_ITEMS[@]}"
fi
PUSHEOF

  sed -i "s|__FAKE_HOME__|$FAKE_HOME|g" "$TEST_DIR/test-push"
  chmod +x "$TEST_DIR/test-push"
}

# ============================================================
echo -e "${CYAN}=== my-bpm-library Conflict Detection Test Suite ===${NC}"
echo ""

# ============================================================
# PULL TESTS
# ============================================================

echo -e "${YELLOW}--- PULL: Flat files (agents/commands/runbooks) ---${NC}"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 1: Pull — new item (no local version)${NC}"
setup_environment
create_test_pull
echo "repo content v1" > "$FAKE_REPO/my/agents/my-test-agent.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-agents 2>&1)
assert_contains "Shows as new" "$OUTPUT" "+ agents/my-test-agent.md (new)"
assert_contains "Count: 1 new" "$OUTPUT" "new=1"
assert "File copied to local" "[[ -f '$FAKE_CLAUDE/agents/my-test-agent.md' ]]"
assert_file_content "Content matches repo" "$FAKE_CLAUDE/agents/my-test-agent.md" "repo content v1"
assert "Baseline created" "[[ -f '$FAKE_CLAUDE/.my-bpm-library-sync' ]]"
assert "Baseline has entry" "grep -q 'agents/my-test-agent.md' '$FAKE_CLAUDE/.my-bpm-library-sync'"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 2: Pull — unchanged item${NC}"
setup_environment
create_test_pull
echo "same content" > "$FAKE_REPO/my/agents/my-test-agent.md"
echo "same content" > "$FAKE_CLAUDE/agents/my-test-agent.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-agents 2>&1)
assert_contains "Count: 1 unchanged" "$OUTPUT" "unchanged=1"
assert_not_contains "Not shown as new/modified" "$OUTPUT" "+"
assert_not_contains "Not shown as modified" "$OUTPUT" "~"
assert "Baseline recorded" "grep -q 'agents/my-test-agent.md' '$FAKE_CLAUDE/.my-bpm-library-sync'"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 3: Pull — modified only in repo (no baseline)${NC}"
setup_environment
create_test_pull
echo "repo v2" > "$FAKE_REPO/my/agents/my-test-agent.md"
echo "local v1" > "$FAKE_CLAUDE/agents/my-test-agent.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-agents 2>&1)
assert_contains "Shows as modified" "$OUTPUT" "~ agents/my-test-agent.md (modified)"
assert_contains "Count: 1 modified" "$OUTPUT" "modified=1"
assert_file_content "Local overwritten with repo" "$FAKE_CLAUDE/agents/my-test-agent.md" "repo v2"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 4: Pull — modified only in repo (with baseline)${NC}"
setup_environment
create_test_pull
echo "original" > "$FAKE_REPO/my/agents/my-test-agent.md"
echo "original" > "$FAKE_CLAUDE/agents/my-test-agent.md"
# Establish baseline
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
# Now change only repo
echo "repo v2" > "$FAKE_REPO/my/agents/my-test-agent.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-agents 2>&1)
assert_contains "Shows as modified" "$OUTPUT" "~ agents/my-test-agent.md (modified)"
assert_file_content "Local updated to repo v2" "$FAKE_CLAUDE/agents/my-test-agent.md" "repo v2"
assert_not_contains "No conflict" "$OUTPUT" "CONFLICT"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 5: Pull — modified only locally (with baseline)${NC}"
setup_environment
create_test_pull
echo "original" > "$FAKE_REPO/my/agents/my-test-agent.md"
echo "original" > "$FAKE_CLAUDE/agents/my-test-agent.md"
# Establish baseline
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
# Now change only local
echo "local v2" > "$FAKE_CLAUDE/agents/my-test-agent.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-agents 2>&1)
# Repo unchanged vs baseline, local changed → repo still == baseline → safe update
# But diff says they differ (local v2 != original in repo) → modified
# Baseline check: local_changed=1, repo_changed=0 → NOT a conflict → overwrite
assert_contains "Shows as modified (safe)" "$OUTPUT" "~ agents/my-test-agent.md (modified)"
assert_not_contains "No conflict" "$OUTPUT" "CONFLICT"
assert_file_content "Local overwritten with repo (repo wins in pull)" "$FAKE_CLAUDE/agents/my-test-agent.md" "original"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 6: Pull — CONFLICT (both sides changed)${NC}"
setup_environment
create_test_pull
echo "original" > "$FAKE_REPO/my/agents/my-test-agent.md"
echo "original" > "$FAKE_CLAUDE/agents/my-test-agent.md"
# Establish baseline
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
# Change BOTH sides
echo "repo v2" > "$FAKE_REPO/my/agents/my-test-agent.md"
echo "local v2" > "$FAKE_CLAUDE/agents/my-test-agent.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-agents 2>&1)
assert_contains "Shows CONFLICT" "$OUTPUT" "X agents/my-test-agent.md (CONFLICT"
assert_contains "Conflict count" "$OUTPUT" "conflicts=1"
assert_contains "Conflict message" "$OUTPUT" "CONFLICTS: 1"
assert_file_content "Local NOT overwritten" "$FAKE_CLAUDE/agents/my-test-agent.md" "local v2"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 7: Pull — CONFLICT + --force (repo wins)${NC}"
setup_environment
create_test_pull
echo "original" > "$FAKE_REPO/my/agents/my-test-agent.md"
echo "original" > "$FAKE_CLAUDE/agents/my-test-agent.md"
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
echo "repo v2" > "$FAKE_REPO/my/agents/my-test-agent.md"
echo "local v2" > "$FAKE_CLAUDE/agents/my-test-agent.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-agents --force 2>&1)
assert_contains "Conflict resolved" "$OUTPUT" "CONFLICT resolved: --force, repo wins"
assert_contains "Count: 1 modified" "$OUTPUT" "modified=1"
assert_contains "No conflicts remaining" "$OUTPUT" "conflicts=0"
assert_file_content "Local overwritten with repo" "$FAKE_CLAUDE/agents/my-test-agent.md" "repo v2"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 8: Pull — dry-run does not change files${NC}"
setup_environment
create_test_pull
echo "repo content" > "$FAKE_REPO/my/agents/my-test-agent.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-agents --dry-run 2>&1)
assert_contains "Shows as new" "$OUTPUT" "+ agents/my-test-agent.md (new)"
assert "File NOT created" "[[ ! -f '$FAKE_CLAUDE/agents/my-test-agent.md' ]]"
assert "Sync state NOT created" "[[ ! -f '$FAKE_CLAUDE/.my-bpm-library-sync' ]]"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 9: Pull — dry-run shows conflicts${NC}"
setup_environment
create_test_pull
echo "original" > "$FAKE_REPO/my/agents/my-test-agent.md"
echo "original" > "$FAKE_CLAUDE/agents/my-test-agent.md"
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
echo "repo v2" > "$FAKE_REPO/my/agents/my-test-agent.md"
echo "local v2" > "$FAKE_CLAUDE/agents/my-test-agent.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-agents --dry-run 2>&1)
assert_contains "Shows CONFLICT in dry-run" "$OUTPUT" "CONFLICT"
assert_file_content "Local unchanged by dry-run" "$FAKE_CLAUDE/agents/my-test-agent.md" "local v2"
echo ""

# ============================================================
echo -e "${YELLOW}--- PULL: Skills (directories) ---${NC}"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 10: Pull — new skill directory${NC}"
setup_environment
create_test_pull
mkdir -p "$FAKE_REPO/my/skills/my-test-skill"
echo "# Test Skill" > "$FAKE_REPO/my/skills/my-test-skill/SKILL.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-skills 2>&1)
assert_contains "Shows as new" "$OUTPUT" "+ skills/my-test-skill (new)"
assert "Directory created" "[[ -d '$FAKE_CLAUDE/skills/my-test-skill' ]]"
assert "SKILL.md copied" "[[ -f '$FAKE_CLAUDE/skills/my-test-skill/SKILL.md' ]]"
assert_file_content "Content correct" "$FAKE_CLAUDE/skills/my-test-skill/SKILL.md" "# Test Skill"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 11: Pull — skill CONFLICT (both changed)${NC}"
setup_environment
create_test_pull
mkdir -p "$FAKE_REPO/my/skills/my-test-skill"
mkdir -p "$FAKE_CLAUDE/skills/my-test-skill"
echo "original" > "$FAKE_REPO/my/skills/my-test-skill/SKILL.md"
echo "original" > "$FAKE_CLAUDE/skills/my-test-skill/SKILL.md"
"$TEST_DIR/test-pull" --only-skills > /dev/null 2>&1
echo "repo change" > "$FAKE_REPO/my/skills/my-test-skill/SKILL.md"
echo "local change" > "$FAKE_CLAUDE/skills/my-test-skill/SKILL.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-skills 2>&1)
assert_contains "Shows CONFLICT" "$OUTPUT" "X skills/my-test-skill (CONFLICT"
assert_file_content "Local NOT overwritten" "$FAKE_CLAUDE/skills/my-test-skill/SKILL.md" "local change"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 12: Pull — skill CONFLICT + --force${NC}"
setup_environment
create_test_pull
mkdir -p "$FAKE_REPO/my/skills/my-test-skill"
mkdir -p "$FAKE_CLAUDE/skills/my-test-skill"
echo "original" > "$FAKE_REPO/my/skills/my-test-skill/SKILL.md"
echo "original" > "$FAKE_CLAUDE/skills/my-test-skill/SKILL.md"
"$TEST_DIR/test-pull" --only-skills > /dev/null 2>&1
echo "repo change" > "$FAKE_REPO/my/skills/my-test-skill/SKILL.md"
echo "local change" > "$FAKE_CLAUDE/skills/my-test-skill/SKILL.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-skills --force 2>&1)
assert_contains "Conflict resolved" "$OUTPUT" "CONFLICT resolved: --force, repo wins"
assert_file_content "Local overwritten with repo" "$FAKE_CLAUDE/skills/my-test-skill/SKILL.md" "repo change"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 13: Pull — skill with multiple files${NC}"
setup_environment
create_test_pull
mkdir -p "$FAKE_REPO/my/skills/my-multi"
echo "# Main" > "$FAKE_REPO/my/skills/my-multi/SKILL.md"
mkdir -p "$FAKE_REPO/my/skills/my-multi/references"
echo "ref data" > "$FAKE_REPO/my/skills/my-multi/references/api.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-skills 2>&1)
assert_contains "Shows as new" "$OUTPUT" "+ skills/my-multi (new)"
assert "references dir copied" "[[ -d '$FAKE_CLAUDE/skills/my-multi/references' ]]"
assert_file_content "ref file correct" "$FAKE_CLAUDE/skills/my-multi/references/api.md" "ref data"
echo ""

# ============================================================
# PUSH TESTS
# ============================================================

echo -e "${YELLOW}--- PUSH: Flat files ---${NC}"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 14: Push — new item (not in repo)${NC}"
setup_environment
create_test_push
echo "local agent" > "$FAKE_CLAUDE/agents/my-new-agent.md"

OUTPUT=$("$TEST_DIR/test-push" --only-agents 2>&1)
assert_contains "Shows as new" "$OUTPUT" "+ agents/my-new-agent.md (new)"
assert_contains "Count: 1 new" "$OUTPUT" "new=1"
assert "File copied to repo" "[[ -f '$FAKE_REPO/my/agents/my-new-agent.md' ]]"
assert_file_content "Content matches local" "$FAKE_REPO/my/agents/my-new-agent.md" "local agent"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 15: Push — unchanged item${NC}"
setup_environment
create_test_push
echo "same" > "$FAKE_CLAUDE/agents/my-test.md"
echo "same" > "$FAKE_REPO/my/agents/my-test.md"

OUTPUT=$("$TEST_DIR/test-push" --only-agents 2>&1)
assert_contains "Count: 1 unchanged" "$OUTPUT" "unchanged=1"
assert_not_contains "Not new" "$OUTPUT" "+"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 16: Push — modified only locally (no baseline)${NC}"
setup_environment
create_test_push
echo "local v2" > "$FAKE_CLAUDE/agents/my-test.md"
echo "repo v1" > "$FAKE_REPO/my/agents/my-test.md"

OUTPUT=$("$TEST_DIR/test-push" --only-agents 2>&1)
assert_contains "Shows as modified" "$OUTPUT" "~ agents/my-test.md (modified)"
assert_file_content "Repo overwritten with local" "$FAKE_REPO/my/agents/my-test.md" "local v2"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 17: Push — modified only locally (with baseline)${NC}"
setup_environment
create_test_push
create_test_pull
echo "original" > "$FAKE_CLAUDE/agents/my-test.md"
echo "original" > "$FAKE_REPO/my/agents/my-test.md"
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
echo "local v2" > "$FAKE_CLAUDE/agents/my-test.md"

OUTPUT=$("$TEST_DIR/test-push" --only-agents 2>&1)
assert_contains "Shows as modified (safe)" "$OUTPUT" "~ agents/my-test.md (modified)"
assert_not_contains "No conflict" "$OUTPUT" "CONFLICT"
assert_file_content "Repo updated" "$FAKE_REPO/my/agents/my-test.md" "local v2"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 18: Push — modified only in repo (with baseline)${NC}"
setup_environment
create_test_push
create_test_pull
echo "original" > "$FAKE_CLAUDE/agents/my-test.md"
echo "original" > "$FAKE_REPO/my/agents/my-test.md"
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
echo "repo v2" > "$FAKE_REPO/my/agents/my-test.md"

OUTPUT=$("$TEST_DIR/test-push" --only-agents 2>&1)
# local unchanged vs baseline, repo changed → NOT a conflict
assert_contains "Shows as modified (safe)" "$OUTPUT" "~ agents/my-test.md (modified)"
assert_not_contains "No conflict" "$OUTPUT" "CONFLICT"
assert_file_content "Repo overwritten with local (local wins in push)" "$FAKE_REPO/my/agents/my-test.md" "original"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 19: Push — CONFLICT (both sides changed)${NC}"
setup_environment
create_test_push
create_test_pull
echo "original" > "$FAKE_CLAUDE/agents/my-test.md"
echo "original" > "$FAKE_REPO/my/agents/my-test.md"
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
echo "local v2" > "$FAKE_CLAUDE/agents/my-test.md"
echo "repo v2" > "$FAKE_REPO/my/agents/my-test.md"

OUTPUT=$("$TEST_DIR/test-push" --only-agents 2>&1)
assert_contains "Shows CONFLICT" "$OUTPUT" "X agents/my-test.md (CONFLICT"
assert_contains "Conflict count" "$OUTPUT" "conflicts=1"
assert_file_content "Repo NOT overwritten" "$FAKE_REPO/my/agents/my-test.md" "repo v2"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 20: Push — CONFLICT + --force (local wins)${NC}"
setup_environment
create_test_push
create_test_pull
echo "original" > "$FAKE_CLAUDE/agents/my-test.md"
echo "original" > "$FAKE_REPO/my/agents/my-test.md"
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
echo "local v2" > "$FAKE_CLAUDE/agents/my-test.md"
echo "repo v2" > "$FAKE_REPO/my/agents/my-test.md"

OUTPUT=$("$TEST_DIR/test-push" --only-agents --force 2>&1)
assert_contains "Conflict resolved" "$OUTPUT" "CONFLICT resolved: --force, local wins"
assert_contains "No conflicts remaining" "$OUTPUT" "conflicts=0"
assert_file_content "Repo overwritten with local" "$FAKE_REPO/my/agents/my-test.md" "local v2"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 21: Push — item in repo but NOT local (deletion warning)${NC}"
setup_environment
create_test_push
echo "local item" > "$FAKE_CLAUDE/agents/my-existing.md"
echo "orphan in repo" > "$FAKE_REPO/my/agents/my-orphan.md"

OUTPUT=$("$TEST_DIR/test-push" --only-agents 2>&1)
assert_contains "Deletion warning" "$OUTPUT" "! agents/my-orphan.md (in repo but not local"
assert_contains "NOT auto-deleted" "$OUTPUT" "NOT auto-deleted"
assert "Orphan file still exists" "[[ -f '$FAKE_REPO/my/agents/my-orphan.md' ]]"
echo ""

# ============================================================
echo -e "${YELLOW}--- PUSH: Skills (directories) ---${NC}"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 22: Push — new skill directory${NC}"
setup_environment
create_test_push
mkdir -p "$FAKE_CLAUDE/skills/my-new-skill"
echo "# New" > "$FAKE_CLAUDE/skills/my-new-skill/SKILL.md"

OUTPUT=$("$TEST_DIR/test-push" --only-skills 2>&1)
assert_contains "Shows as new" "$OUTPUT" "+ skills/my-new-skill (new)"
assert "Directory created in repo" "[[ -d '$FAKE_REPO/my/skills/my-new-skill' ]]"
assert_file_content "SKILL.md correct" "$FAKE_REPO/my/skills/my-new-skill/SKILL.md" "# New"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 23: Push — skill CONFLICT (both changed)${NC}"
setup_environment
create_test_push
create_test_pull
mkdir -p "$FAKE_CLAUDE/skills/my-sk"
mkdir -p "$FAKE_REPO/my/skills/my-sk"
echo "original" > "$FAKE_CLAUDE/skills/my-sk/SKILL.md"
echo "original" > "$FAKE_REPO/my/skills/my-sk/SKILL.md"
"$TEST_DIR/test-pull" --only-skills > /dev/null 2>&1
echo "local change" > "$FAKE_CLAUDE/skills/my-sk/SKILL.md"
echo "repo change" > "$FAKE_REPO/my/skills/my-sk/SKILL.md"

OUTPUT=$("$TEST_DIR/test-push" --only-skills 2>&1)
assert_contains "Shows CONFLICT" "$OUTPUT" "X skills/my-sk (CONFLICT"
assert_file_content "Repo NOT overwritten" "$FAKE_REPO/my/skills/my-sk/SKILL.md" "repo change"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 24: Push — skill CONFLICT + --force (local wins)${NC}"
setup_environment
create_test_push
create_test_pull
mkdir -p "$FAKE_CLAUDE/skills/my-sk"
mkdir -p "$FAKE_REPO/my/skills/my-sk"
echo "original" > "$FAKE_CLAUDE/skills/my-sk/SKILL.md"
echo "original" > "$FAKE_REPO/my/skills/my-sk/SKILL.md"
"$TEST_DIR/test-pull" --only-skills > /dev/null 2>&1
echo "local change" > "$FAKE_CLAUDE/skills/my-sk/SKILL.md"
echo "repo change" > "$FAKE_REPO/my/skills/my-sk/SKILL.md"

OUTPUT=$("$TEST_DIR/test-push" --only-skills --force 2>&1)
assert_contains "Conflict resolved" "$OUTPUT" "CONFLICT resolved: --force, local wins"
assert_file_content "Repo overwritten with local" "$FAKE_REPO/my/skills/my-sk/SKILL.md" "local change"
echo ""

# ============================================================
echo -e "${YELLOW}--- EDGE CASES ---${NC}"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 25: Multiple items — mixed states${NC}"
setup_environment
create_test_pull
# Item 1: new
echo "new agent" > "$FAKE_REPO/my/agents/my-alpha.md"
# Item 2: unchanged
echo "same" > "$FAKE_REPO/my/agents/my-beta.md"
echo "same" > "$FAKE_CLAUDE/agents/my-beta.md"
# Item 3: modified (no baseline)
echo "repo v2" > "$FAKE_REPO/my/agents/my-gamma.md"
echo "local v1" > "$FAKE_CLAUDE/agents/my-gamma.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-agents 2>&1)
assert_contains "Alpha is new" "$OUTPUT" "+ agents/my-alpha.md (new)"
assert_contains "Gamma is modified" "$OUTPUT" "~ agents/my-gamma.md (modified)"
assert_contains "Counts correct" "$OUTPUT" "new=1 modified=1 unchanged=1"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 26: Baseline persists across runs${NC}"
setup_environment
create_test_pull
echo "v1" > "$FAKE_REPO/my/agents/my-persist.md"
echo "v1" > "$FAKE_CLAUDE/agents/my-persist.md"
# Run 1: establish baseline
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
assert "Sync file exists after run 1" "[[ -f '$FAKE_CLAUDE/.my-bpm-library-sync' ]]"
HASH1=$(grep 'agents/my-persist.md' "$FAKE_CLAUDE/.my-bpm-library-sync" | cut -d' ' -f1)
assert "Hash recorded" "[[ -n '$HASH1' ]]"
# Run 2: unchanged — baseline should stay
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
HASH2=$(grep 'agents/my-persist.md' "$FAKE_CLAUDE/.my-bpm-library-sync" | cut -d' ' -f1)
assert "Hash unchanged after run 2" "[[ '$HASH1' == '$HASH2' ]]"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 27: Push dry-run does not save sync state${NC}"
setup_environment
create_test_push
echo "new" > "$FAKE_CLAUDE/agents/my-drytest.md"
# Remove sync file if exists
rm -f "$FAKE_CLAUDE/.my-bpm-library-sync"

OUTPUT=$("$TEST_DIR/test-push" --only-agents --dry-run 2>&1)
assert_contains "Shows as new" "$OUTPUT" "+ agents/my-drytest.md (new)"
# Sync state should not be created in dry-run... but our script creates it empty
# Actually save_sync_state returns early on dry-run, so file should not exist
# unless it existed before
assert "Sync state NOT created" "[[ ! -f '$FAKE_CLAUDE/.my-bpm-library-sync' ]]"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 28: Pull updates baseline after successful sync${NC}"
setup_environment
create_test_pull
echo "v1" > "$FAKE_REPO/my/agents/my-evolve.md"
# Run 1: new item
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
HASH_V1=$(grep 'agents/my-evolve.md' "$FAKE_CLAUDE/.my-bpm-library-sync" | cut -d' ' -f1)
# Change repo
echo "v2" > "$FAKE_REPO/my/agents/my-evolve.md"
# Run 2: modified
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
HASH_V2=$(grep 'agents/my-evolve.md' "$FAKE_CLAUDE/.my-bpm-library-sync" | cut -d' ' -f1)
assert "Baseline updated after sync" "[[ '$HASH_V1' != '$HASH_V2' ]]"
assert_file_content "Local updated to v2" "$FAKE_CLAUDE/agents/my-evolve.md" "v2"
# Now change repo again
echo "v3" > "$FAKE_REPO/my/agents/my-evolve.md"
# And change local
echo "local v3" > "$FAKE_CLAUDE/agents/my-evolve.md"
# This should CONFLICT because baseline = v2, local = local v3, repo = v3
OUTPUT=$("$TEST_DIR/test-pull" --only-agents 2>&1)
assert_contains "Conflict after baseline update" "$OUTPUT" "CONFLICT"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 29: Push then Pull round-trip (no conflict)${NC}"
setup_environment
create_test_push
create_test_pull
echo "original" > "$FAKE_CLAUDE/commands/my-cmd.md"
echo "original" > "$FAKE_REPO/my/commands/my-cmd.md"
# Establish baseline via pull
"$TEST_DIR/test-pull" --only-commands > /dev/null 2>&1
# Modify locally
echo "local v2" > "$FAKE_CLAUDE/commands/my-cmd.md"
# Push (local → repo)
"$TEST_DIR/test-push" --only-commands > /dev/null 2>&1
assert_file_content "Repo updated by push" "$FAKE_REPO/my/commands/my-cmd.md" "local v2"
# Now pull should see no changes (both sides same after push)
OUTPUT=$("$TEST_DIR/test-pull" --only-commands 2>&1)
assert_contains "Unchanged after round-trip" "$OUTPUT" "unchanged=1"
assert_not_contains "No conflict" "$OUTPUT" "CONFLICT"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 30: Conflict skipped — baseline NOT updated${NC}"
setup_environment
create_test_pull
echo "original" > "$FAKE_REPO/my/agents/my-skip.md"
echo "original" > "$FAKE_CLAUDE/agents/my-skip.md"
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
HASH_BEFORE=$(grep 'agents/my-skip.md' "$FAKE_CLAUDE/.my-bpm-library-sync" | cut -d' ' -f1)
echo "repo v2" > "$FAKE_REPO/my/agents/my-skip.md"
echo "local v2" > "$FAKE_CLAUDE/agents/my-skip.md"
"$TEST_DIR/test-pull" --only-agents > /dev/null 2>&1
HASH_AFTER=$(grep 'agents/my-skip.md' "$FAKE_CLAUDE/.my-bpm-library-sync" | cut -d' ' -f1)
assert "Baseline unchanged on conflict skip" "[[ '$HASH_BEFORE' == '$HASH_AFTER' ]]"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 31: Category filter --only-skills ignores agents${NC}"
setup_environment
create_test_pull
mkdir -p "$FAKE_REPO/my/skills/my-filtered"
echo "skill" > "$FAKE_REPO/my/skills/my-filtered/SKILL.md"
echo "agent" > "$FAKE_REPO/my/agents/my-filtered.md"

OUTPUT=$("$TEST_DIR/test-pull" --only-skills 2>&1)
assert_contains "Skill pulled" "$OUTPUT" "skills/my-filtered"
assert_not_contains "Agent NOT pulled" "$OUTPUT" "agents/my-filtered"
assert "Agent file NOT created" "[[ ! -f '$FAKE_CLAUDE/agents/my-filtered.md' ]]"
echo ""

# ----------------------------------------------------------
echo -e "${CYAN}Test 32: Push — skill deleted locally shows warning${NC}"
setup_environment
create_test_push
# Skill exists in repo but NOT locally
mkdir -p "$FAKE_REPO/my/skills/my-deleted-skill"
echo "orphan" > "$FAKE_REPO/my/skills/my-deleted-skill/SKILL.md"
# Need at least one local skill so the glob matches
mkdir -p "$FAKE_CLAUDE/skills/my-existing"
echo "exists" > "$FAKE_CLAUDE/skills/my-existing/SKILL.md"

OUTPUT=$("$TEST_DIR/test-push" --only-skills 2>&1)
assert_contains "Deletion warning for skill" "$OUTPUT" "! skills/my-deleted-skill"
assert "Orphan skill NOT deleted" "[[ -d '$FAKE_REPO/my/skills/my-deleted-skill' ]]"
echo ""

# ============================================================
# SUMMARY
# ============================================================

echo ""
echo -e "${CYAN}================================================${NC}"
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo -e "${GREEN}ALL $TOTAL_COUNT TESTS PASSED${NC}"
else
  echo -e "${RED}$FAIL_COUNT/$TOTAL_COUNT TESTS FAILED${NC} (${GREEN}$PASS_COUNT passed${NC})"
fi
echo -e "${CYAN}================================================${NC}"

exit "$FAIL_COUNT"
