#!/usr/bin/env bash
#
# migrate-my-to-my-bpm.sh - One-time migration for existing bcgasl installations
#
# Renames local my-* items to my-bpm-* and patches internal references.
# Only touches known BPM items (hardcoded list) — other my-* items are untouched.
#
# Usage:
#   ./migrate-my-to-my-bpm.sh                Run migration
#   ./migrate-my-to-my-bpm.sh --dry-run      Show what would change without applying
#   ./migrate-my-to-my-bpm.sh --verbose      Show detailed output
#   ./migrate-my-to-my-bpm.sh --help         Show this help
#
set -euo pipefail
IFS=$'\n\t'

VERSION="1.0.0"

# ── Color helpers ────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${GREEN}[INFO]${RESET}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; }
debug() { [[ "${VERBOSE:-0}" -eq 1 ]] && printf "${CYAN}[DEBUG]${RESET} %s\n" "$*"; }

# ── Hardcoded BPM item lists ────────────────────────────────────────────────

SKILLS=(
  api-contract
  appsec-threatlite
  bash-secure-script
  bootstrap-ui
  config-secrets
  curlbash-installer
  datatables
  flightphp-pro
  jquery-ajax-forms
  library-manager
  linux-admin
  linux-audit
  llm-selection
  mariadb-migrations
  n8n-reliability
  php-crud-api-review
  php-flight-mvc
  redis-keyspace
  release-ops
  repo-scaffold
  skill-creator
  skill-optimizer
  team-milestones
  test-harness
  tls-http-headers
)

AGENTS=(
  orchestrator-planner
  backend-bash-php
  data-mariadb-redis
  qa-tester
  security-reviewer
  workflow-n8n-api
)

COMMANDS=(
  experteam-openissues
  library-pull
  library-push
  refactor-repo
)

# ── Globals ──────────────────────────────────────────────────────────────────

DRY_RUN=0
VERBOSE=0
TARGET_DIR=""
BACKUP_DIR=""

# Counters
RENAMED_COUNT=0
SKIPPED_COUNT=0
PATCHED_COUNT=0
MISSING_COUNT=0

# ── Functions ────────────────────────────────────────────────────────────────

show_help() {
  cat <<'EOF'
migrate-my-to-my-bpm.sh - One-time migration for bcgasl installations

Renames local my-* items to my-bpm-* and patches internal references.
Only touches known BPM items — other my-* items are left untouched.

Usage:
  ./migrate-my-to-my-bpm.sh                Run migration
  ./migrate-my-to-my-bpm.sh --dry-run      Show what would change without applying
  ./migrate-my-to-my-bpm.sh --verbose      Show detailed output
  ./migrate-my-to-my-bpm.sh --help         Show this help

What it does:
  1. Detects your Claude config directory (~/.claude or ~/.config/claude)
  2. Creates a timestamped backup of affected directories
  3. Renames my-{name} → my-bpm-{name} for all known BPM items
  4. Patches internal references inside renamed files
  5. Prints a summary with rollback instructions
EOF
}

detect_target_dir() {
  if [[ -f "$HOME/.claude/settings.json" ]]; then
    echo "$HOME/.claude"
  elif [[ -f "$HOME/.config/claude/settings.json" ]]; then
    echo "$HOME/.config/claude"
  elif [[ -d "$HOME/.claude" ]]; then
    echo "$HOME/.claude"
  elif [[ -d "$HOME/.config/claude" ]]; then
    echo "$HOME/.config/claude"
  else
    echo ""
  fi
}

create_backup() {
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$TARGET_DIR/backup-migrate-$timestamp"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Would create backup at: $BACKUP_DIR"
    return 0
  fi

  mkdir -p "$BACKUP_DIR"

  # Only back up my-* items (not the entire directory which can be huge)
  for dir in skills agents commands; do
    if [[ -d "$TARGET_DIR/$dir" ]]; then
      local found=0
      for item in "$TARGET_DIR/$dir"/my-*; do
        [[ -e "$item" ]] || continue
        # Skip items already using my-bpm- prefix
        [[ "$(basename "$item")" == my-bpm-* ]] && continue
        if [[ "$found" -eq 0 ]]; then
          mkdir -p "$BACKUP_DIR/$dir"
          found=1
        fi
        cp -r "$item" "$BACKUP_DIR/$dir/"
      done
      [[ "$found" -eq 1 ]] && debug "Backed up my-* items from $dir/"
    fi
  done

  info "Backup created: $BACKUP_DIR"
}

# Rename a single item (directory or file)
# Usage: rename_item <category> <short_name> <type>
#   type = "dir" for skills, "file" for agents/commands
rename_item() {
  local category="$1"
  local name="$2"
  local item_type="$3"

  local old_name="my-${name}"
  local new_name="my-bpm-${name}"

  if [[ "$item_type" == "dir" ]]; then
    local old_path="$TARGET_DIR/$category/$old_name"
    local new_path="$TARGET_DIR/$category/$new_name"
  else
    local old_path="$TARGET_DIR/$category/${old_name}.md"
    local new_path="$TARGET_DIR/$category/${new_name}.md"
  fi

  # Already migrated
  if [[ "$item_type" == "dir" && -d "$new_path" ]] || [[ "$item_type" == "file" && -f "$new_path" ]]; then
    debug "Already migrated: $category/$new_name (skipping)"
    ((SKIPPED_COUNT++)) || true
    return 0
  fi

  # Old item does not exist
  if [[ "$item_type" == "dir" && ! -d "$old_path" ]] || [[ "$item_type" == "file" && ! -f "$old_path" ]]; then
    debug "Not installed: $category/$old_name (skipping)"
    ((MISSING_COUNT++)) || true
    return 0
  fi

  # Rename
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf "  ${BOLD}RENAME${RESET} %s/%s → %s\n" "$category" "$old_name" "$new_name"
  else
    mv "$old_path" "$new_path"
    printf "  ${GREEN}RENAMED${RESET} %s/%s → %s\n" "$category" "$old_name" "$new_name"
  fi
  ((RENAMED_COUNT++)) || true
}

# Build sed expression to replace all known old names with new names
build_sed_expression() {
  local sed_expr=""
  local all_names=()

  for name in "${SKILLS[@]}"; do all_names+=("$name"); done
  for name in "${AGENTS[@]}"; do all_names+=("$name"); done
  for name in "${COMMANDS[@]}"; do all_names+=("$name"); done

  for name in "${all_names[@]}"; do
    # Step 1: Protect existing my-bpm-{name} with placeholder
    sed_expr+="s/my-bpm-${name}/MY_BPM_HOLD_${name//[-]/_}/g; "
    # Step 2: Replace my-{name} with my-bpm-{name}
    sed_expr+="s/my-${name}/my-bpm-${name}/g; "
    # Step 3: Restore placeholder
    sed_expr+="s/MY_BPM_HOLD_${name//[-]/_}/my-bpm-${name}/g; "
  done

  echo "$sed_expr"
}

# Patch references inside all renamed files
patch_references() {
  local sed_expr
  sed_expr="$(build_sed_expression)"

  debug "Sed expression length: ${#sed_expr} chars"

  # Collect all .md files in renamed (or to-be-renamed) items
  # In dry-run mode, files are still at old paths
  local files_to_patch=()

  # Skills (directories — patch all .md files inside)
  for name in "${SKILLS[@]}"; do
    local skill_dir="$TARGET_DIR/skills/my-bpm-${name}"
    # In dry-run, check old path
    [[ ! -d "$skill_dir" ]] && skill_dir="$TARGET_DIR/skills/my-${name}"
    if [[ -d "$skill_dir" ]]; then
      while IFS= read -r -d '' mdfile; do
        files_to_patch+=("$mdfile")
      done < <(find "$skill_dir" -name '*.md' -print0 2>/dev/null)
    fi
  done

  # Agents (flat files)
  for name in "${AGENTS[@]}"; do
    local agent_file="$TARGET_DIR/agents/my-bpm-${name}.md"
    [[ ! -f "$agent_file" ]] && agent_file="$TARGET_DIR/agents/my-${name}.md"
    [[ -f "$agent_file" ]] && files_to_patch+=("$agent_file")
  done

  # Commands (flat files)
  for name in "${COMMANDS[@]}"; do
    local cmd_file="$TARGET_DIR/commands/my-bpm-${name}.md"
    [[ ! -f "$cmd_file" ]] && cmd_file="$TARGET_DIR/commands/my-${name}.md"
    [[ -f "$cmd_file" ]] && files_to_patch+=("$cmd_file")
  done

  if [[ ${#files_to_patch[@]} -eq 0 ]]; then
    debug "No files to patch"
    return 0
  fi

  info "Patching references in ${#files_to_patch[@]} file(s)..."

  for filepath in "${files_to_patch[@]}"; do
    local rel_path="${filepath#"$TARGET_DIR"/}"

    # Check if file contains any old references worth patching
    # The sed expression is safe to run on any file (idempotent),
    # so we just check if the file has any my-{name} strings at all
    local has_old_ref=0
    for name in "${SKILLS[@]}" "${AGENTS[@]}" "${COMMANDS[@]}"; do
      if grep -q "my-${name}" "$filepath" 2>/dev/null; then
        has_old_ref=1
        break
      fi
    done

    if [[ "$has_old_ref" -eq 0 ]]; then
      debug "No old references in: $rel_path"
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf "  ${BOLD}PATCH${RESET}  %s\n" "$rel_path"
    else
      sed -i "$sed_expr" "$filepath"
      printf "  ${GREEN}PATCHED${RESET} %s\n" "$rel_path"
    fi
    ((PATCHED_COUNT++)) || true
  done
}

print_summary() {
  echo ""
  printf "${BOLD}── Migration Summary ──${RESET}\n"
  echo ""
  printf "  Renamed:  %d item(s)\n" "$RENAMED_COUNT"
  printf "  Skipped:  %d item(s) (already migrated)\n" "$SKIPPED_COUNT"
  printf "  Patched:  %d file(s) (internal references)\n" "$PATCHED_COUNT"
  printf "  Missing:  %d item(s) (not installed)\n" "$MISSING_COUNT"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo ""
    warn "DRY RUN — no changes were made"
  fi

  if [[ "$RENAMED_COUNT" -gt 0 ]] && [[ "$DRY_RUN" -eq 0 ]] && [[ -n "$BACKUP_DIR" ]]; then
    echo ""
    info "To rollback this migration:"
    echo "  cp -r ${BACKUP_DIR}/* ${TARGET_DIR}/"
    echo "  rm -rf ${BACKUP_DIR}"
  fi

  if [[ "$RENAMED_COUNT" -eq 0 ]] && [[ "$SKIPPED_COUNT" -gt 0 ]]; then
    echo ""
    info "All items already migrated. Nothing to do."
  fi

  if [[ "$RENAMED_COUNT" -eq 0 ]] && [[ "$SKIPPED_COUNT" -eq 0 ]]; then
    echo ""
    info "No BPM items found. Nothing to migrate."
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)  DRY_RUN=1; shift ;;
      --verbose)  VERBOSE=1; shift ;;
      -h|--help)  show_help; exit 0 ;;
      -v|--version) echo "migrate-my-to-my-bpm.sh v$VERSION"; exit 0 ;;
      *)
        error "Unknown option: $1"
        echo "Run with --help for usage."
        exit 1
        ;;
    esac
  done

  printf "${BOLD}migrate-my-to-my-bpm.sh v%s${RESET}\n" "$VERSION"
  echo ""

  # Step 1: Detect target directory
  TARGET_DIR="$(detect_target_dir)"
  if [[ -z "$TARGET_DIR" ]]; then
    error "No Claude configuration directory found."
    error "Expected ~/.claude/ or ~/.config/claude/"
    exit 1
  fi
  info "Target directory: $TARGET_DIR"

  # Verify at least one category directory exists
  local has_items=0
  for dir in skills agents commands; do
    [[ -d "$TARGET_DIR/$dir" ]] && has_items=1
  done
  if [[ "$has_items" -eq 0 ]]; then
    warn "No skills/, agents/, or commands/ directories found in $TARGET_DIR"
    warn "Nothing to migrate."
    exit 0
  fi

  # Step 2: Create backup
  echo ""
  create_backup

  # Step 3: Rename items
  echo ""
  info "Renaming items..."

  # Skills (directories)
  for name in "${SKILLS[@]}"; do
    rename_item "skills" "$name" "dir"
  done

  # Agents (flat files)
  for name in "${AGENTS[@]}"; do
    rename_item "agents" "$name" "file"
  done

  # Commands (flat files)
  for name in "${COMMANDS[@]}"; do
    rename_item "commands" "$name" "file"
  done

  # Step 4: Patch internal references
  echo ""
  patch_references

  # Step 5: Summary
  print_summary
}

main "$@"
