#!/usr/bin/env bash
#
# migrate-to-c-bpm.sh - One-time migration from my-bpm-* to c-bpm-{type}-*
#
# Renames local my-bpm-* items to the new c-bpm-{type}-{name} convention:
#   Skills:   my-bpm-{name}    -> c-bpm-sk-{name}
#   Commands: my-bpm-{name}.md -> c-bpm-cm-{name}.md
#   Agents:   my-bpm-{name}.md -> c-bpm-ag-{name}.md
#   Runbooks: my-bpm-{name}.md -> c-bpm-rb-{name}.md
#
# Also patches internal references using a targeted (known-item) approach
# with placeholder-based sed to avoid double-replacement.
#
# Usage:
#   ./migrate-to-c-bpm.sh                Run migration
#   ./migrate-to-c-bpm.sh --dry-run      Show what would change without applying
#   ./migrate-to-c-bpm.sh --verbose       Show detailed output
#   ./migrate-to-c-bpm.sh --help          Show this help
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
debug() { [[ "${VERBOSE:-0}" -eq 1 ]] && printf "${CYAN}[DEBUG]${RESET} %s\n" "$*" || true; }

# ── Known BPM item lists ─────────────────────────────────────────────────────

SKILLS=(
  api-contract
  appsec-threatlite
  auditor
  bash-secure-script
  bootstrap-ui
  config-secrets
  curlbash-installer
  datatables
  flightphp-pro
  jquery-ajax-forms
  library-manager
  linux-admin
  linux-archive
  linux-audit
  llm-selection
  mariadb-migrations
  milestone-type
  n8n-reliability
  php-crud-api-review
  php-flight-mvc
  question-auditor
  redis-keyspace
  release-ops
  repo-scaffold
  skill-creator
  skill-optimizer
  test-harness
  tls-http-headers
)

COMMANDS=(
  library-compare
  library-pull
  library-push
  openissues-list
  openissues-team
  refactor-repo
  skill-creator
  skill-optimizer
)

AGENTS=(
  # Agent definitions deprecated — unique content merged into skills
  # (c-bpm-sk-llm-selection, c-bpm-sk-appsec-threatlite)
)

# No runbooks list provided — discover dynamically
RUNBOOKS=()

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
migrate-to-c-bpm.sh - One-time migration from my-bpm-* to c-bpm-{type}-*

Renames local my-bpm-* items to the new c-bpm-{type}-{name} convention
and patches internal references using a targeted replacement approach.

Usage:
  ./migrate-to-c-bpm.sh                Run migration
  ./migrate-to-c-bpm.sh --dry-run      Show what would change without applying
  ./migrate-to-c-bpm.sh --verbose       Show detailed output
  ./migrate-to-c-bpm.sh --help          Show this help

Naming convention:
  Skills:   my-bpm-{name}    -> c-bpm-sk-{name}   (directories)
  Commands: my-bpm-{name}.md -> c-bpm-cm-{name}.md (files)
  Agents:   my-bpm-{name}.md -> c-bpm-ag-{name}.md (files)
  Runbooks: my-bpm-{name}.md -> c-bpm-rb-{name}.md (files)

What it does:
  1. Detects your Claude config directory (~/.claude or ~/.config/claude)
  2. Creates a timestamped backup of affected items
  3. Renames my-bpm-{name} items to c-bpm-{type}-{name}
  4. Patches internal references inside renamed files
  5. Renames sync state file (.my-bpm-library-sync -> .c-bpm-library-sync)
  6. Prints a summary with rollback instructions
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

discover_runbooks() {
  if [[ -d "$TARGET_DIR/runbooks" ]]; then
    local name
    for item in "$TARGET_DIR/runbooks"/my-bpm-*.md; do
      [[ -e "$item" ]] || continue
      name="$(basename "$item" .md)"
      name="${name#my-bpm-}"
      RUNBOOKS+=("$name")
    done
  fi
  debug "Discovered ${#RUNBOOKS[@]} runbook(s)"
}

create_backup() {
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$TARGET_DIR/backup-migrate-c-bpm-$timestamp"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Would create backup at: $BACKUP_DIR"
    return 0
  fi

  mkdir -p "$BACKUP_DIR"

  for dir in skills agents commands runbooks; do
    if [[ -d "$TARGET_DIR/$dir" ]]; then
      local found=0
      for item in "$TARGET_DIR/$dir"/my-bpm-*; do
        [[ -e "$item" ]] || continue
        if [[ "$found" -eq 0 ]]; then
          mkdir -p "$BACKUP_DIR/$dir"
          found=1
        fi
        cp -r "$item" "$BACKUP_DIR/$dir/"
      done
      [[ "$found" -eq 1 ]] && debug "Backed up my-bpm-* items from $dir/" || true
    fi
  done

  # Back up sync state file if it exists
  if [[ -f "$TARGET_DIR/.my-bpm-library-sync" ]]; then
    cp "$TARGET_DIR/.my-bpm-library-sync" "$BACKUP_DIR/"
    debug "Backed up .my-bpm-library-sync"
  fi

  info "Backup created: $BACKUP_DIR"
}

# Rename a single item (directory or file)
# Usage: rename_item <category> <short_name> <type_prefix> <item_type>
#   type_prefix = "sk", "cm", "ag", "rb"
#   item_type   = "dir" for skills, "file" for agents/commands/runbooks
rename_item() {
  local category="$1"
  local name="$2"
  local type_prefix="$3"
  local item_type="$4"

  local old_name="my-bpm-${name}"
  local new_name="c-bpm-${type_prefix}-${name}"

  local old_path new_path
  if [[ "$item_type" == "dir" ]]; then
    old_path="$TARGET_DIR/$category/$old_name"
    new_path="$TARGET_DIR/$category/$new_name"
  else
    old_path="$TARGET_DIR/$category/${old_name}.md"
    new_path="$TARGET_DIR/$category/${new_name}.md"
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
    printf "  ${BOLD}RENAME${RESET} %s/%s -> %s\n" "$category" "$old_name" "$new_name"
  else
    mv "$old_path" "$new_path"
    printf "  ${GREEN}RENAMED${RESET} %s/%s -> %s\n" "$category" "$old_name" "$new_name"
  fi
  ((RENAMED_COUNT++)) || true
}

# Build sed expression using placeholder approach to avoid double-replacement
# Strategy:
#   1. Protect existing c-bpm-{type}-{x} with placeholder __CBPM{TYPE}_{X}__
#   2. Replace my-bpm-{x} -> c-bpm-{type}-{x} for each category
#   3. Restore placeholders
build_sed_expression() {
  local sed_expr=""

  # Helper: convert name to uppercase placeholder-safe form (hyphens -> underscores)
  # We inline this since we cannot call functions from within the loop easily
  local placeholder_name

  # Skills: my-bpm-{name} -> c-bpm-sk-{name}
  for name in "${SKILLS[@]}"; do
    placeholder_name="${name//-/_}"
    placeholder_name="$(echo "$placeholder_name" | tr '[:lower:]' '[:upper:]')"
    sed_expr+="s/c-bpm-sk-${name}/__CBPMSK_${placeholder_name}__/g; "
    sed_expr+="s/my-bpm-${name}/c-bpm-sk-${name}/g; "
    sed_expr+="s/__CBPMSK_${placeholder_name}__/c-bpm-sk-${name}/g; "
  done

  # Commands: my-bpm-{name} -> c-bpm-cm-{name}
  for name in "${COMMANDS[@]}"; do
    placeholder_name="${name//-/_}"
    placeholder_name="$(echo "$placeholder_name" | tr '[:lower:]' '[:upper:]')"
    sed_expr+="s/c-bpm-cm-${name}/__CBPMCM_${placeholder_name}__/g; "
    sed_expr+="s/my-bpm-${name}/c-bpm-cm-${name}/g; "
    sed_expr+="s/__CBPMCM_${placeholder_name}__/c-bpm-cm-${name}/g; "
  done

  # Agents: my-bpm-{name} -> c-bpm-ag-{name}
  for name in "${AGENTS[@]}"; do
    placeholder_name="${name//-/_}"
    placeholder_name="$(echo "$placeholder_name" | tr '[:lower:]' '[:upper:]')"
    sed_expr+="s/c-bpm-ag-${name}/__CBPMAG_${placeholder_name}__/g; "
    sed_expr+="s/my-bpm-${name}/c-bpm-ag-${name}/g; "
    sed_expr+="s/__CBPMAG_${placeholder_name}__/c-bpm-ag-${name}/g; "
  done

  # Runbooks: my-bpm-{name} -> c-bpm-rb-{name}
  for name in "${RUNBOOKS[@]}"; do
    placeholder_name="${name//-/_}"
    placeholder_name="$(echo "$placeholder_name" | tr '[:lower:]' '[:upper:]')"
    sed_expr+="s/c-bpm-rb-${name}/__CBPMRB_${placeholder_name}__/g; "
    sed_expr+="s/my-bpm-${name}/c-bpm-rb-${name}/g; "
    sed_expr+="s/__CBPMRB_${placeholder_name}__/c-bpm-rb-${name}/g; "
  done

  echo "$sed_expr"
}

# Collect all files that need patching
collect_files_to_patch() {
  local files=()

  # Skills (directories - patch all .md files inside)
  for name in "${SKILLS[@]}"; do
    local skill_dir="$TARGET_DIR/skills/c-bpm-sk-${name}"
    # In dry-run, check old path since rename did not happen
    [[ ! -d "$skill_dir" ]] && skill_dir="$TARGET_DIR/skills/my-bpm-${name}"
    if [[ -d "$skill_dir" ]]; then
      while IFS= read -r -d '' mdfile; do
        files+=("$mdfile")
      done < <(find "$skill_dir" -name '*.md' -print0 2>/dev/null)
    fi
  done

  # Agents (flat files)
  for name in "${AGENTS[@]}"; do
    local agent_file="$TARGET_DIR/agents/c-bpm-ag-${name}.md"
    [[ ! -f "$agent_file" ]] && agent_file="$TARGET_DIR/agents/my-bpm-${name}.md"
    [[ -f "$agent_file" ]] && files+=("$agent_file")
  done

  # Commands (flat files)
  for name in "${COMMANDS[@]}"; do
    local cmd_file="$TARGET_DIR/commands/c-bpm-cm-${name}.md"
    [[ ! -f "$cmd_file" ]] && cmd_file="$TARGET_DIR/commands/my-bpm-${name}.md"
    [[ -f "$cmd_file" ]] && files+=("$cmd_file")
  done

  # Runbooks (flat files)
  for name in "${RUNBOOKS[@]}"; do
    local rb_file="$TARGET_DIR/runbooks/c-bpm-rb-${name}.md"
    [[ ! -f "$rb_file" ]] && rb_file="$TARGET_DIR/runbooks/my-bpm-${name}.md"
    [[ -f "$rb_file" ]] && files+=("$rb_file")
  done

  # Print files (null-separated for safe consumption)
  printf '%s\0' "${files[@]}"
}

# Patch references inside all renamed files
patch_references() {
  local sed_expr
  sed_expr="$(build_sed_expression)"

  debug "Sed expression length: ${#sed_expr} chars"

  local files_to_patch=()
  while IFS= read -r -d '' f; do
    files_to_patch+=("$f")
  done < <(collect_files_to_patch)

  if [[ ${#files_to_patch[@]} -eq 0 ]]; then
    debug "No files to patch"
    return 0
  fi

  info "Patching references in ${#files_to_patch[@]} file(s)..."

  # Detect sed -i syntax (GNU vs BSD/macOS)
  local sed_i_flag
  if sed --version 2>/dev/null | grep -q 'GNU'; then
    sed_i_flag=(-i)
  else
    sed_i_flag=(-i '')
  fi

  for filepath in "${files_to_patch[@]}"; do
    local rel_path="${filepath#"$TARGET_DIR"/}"

    # Check if file contains any my-bpm- references worth patching
    if ! grep -q 'my-bpm-' "$filepath" 2>/dev/null; then
      debug "No my-bpm- references in: $rel_path"
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf "  ${BOLD}PATCH${RESET}  %s\n" "$rel_path"
    else
      sed "${sed_i_flag[@]}" "$sed_expr" "$filepath"
      printf "  ${GREEN}PATCHED${RESET} %s\n" "$rel_path"
    fi
    ((PATCHED_COUNT++)) || true
  done
}

# Rename sync state file
rename_sync_state() {
  local old_sync="$TARGET_DIR/.my-bpm-library-sync"
  local new_sync="$TARGET_DIR/.c-bpm-library-sync"

  if [[ -f "$new_sync" ]]; then
    debug "Sync state file already renamed: .c-bpm-library-sync (skipping)"
    return 0
  fi

  if [[ ! -f "$old_sync" ]]; then
    debug "No sync state file found: .my-bpm-library-sync (skipping)"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf "  ${BOLD}RENAME${RESET} .my-bpm-library-sync -> .c-bpm-library-sync\n"
  else
    mv "$old_sync" "$new_sync"
    printf "  ${GREEN}RENAMED${RESET} .my-bpm-library-sync -> .c-bpm-library-sync\n"
  fi
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
    warn "DRY RUN -- no changes were made"
  fi

  if [[ "$RENAMED_COUNT" -gt 0 ]] && [[ "$DRY_RUN" -eq 0 ]] && [[ -n "${BACKUP_DIR:-}" ]]; then
    echo ""
    info "Backup location: $BACKUP_DIR"
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
      -v|--version) echo "migrate-to-c-bpm.sh v$VERSION"; exit 0 ;;
      *)
        error "Unknown option: $1"
        echo "Run with --help for usage."
        exit 1
        ;;
    esac
  done

  printf "${BOLD}migrate-to-c-bpm.sh v%s${RESET}\n" "$VERSION"
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
  for dir in skills agents commands runbooks; do
    [[ -d "$TARGET_DIR/$dir" ]] && has_items=1
  done
  if [[ "$has_items" -eq 0 ]]; then
    warn "No skills/, agents/, commands/, or runbooks/ directories found in $TARGET_DIR"
    warn "Nothing to migrate."
    exit 0
  fi

  # Discover runbooks dynamically
  discover_runbooks

  # Step 2: Create backup
  echo ""
  create_backup

  # Step 3: Rename items
  echo ""
  info "Renaming items..."

  # Skills (directories)
  for name in "${SKILLS[@]}"; do
    rename_item "skills" "$name" "sk" "dir"
  done

  # Agents (flat files)
  for name in "${AGENTS[@]}"; do
    rename_item "agents" "$name" "ag" "file"
  done

  # Commands (flat files)
  for name in "${COMMANDS[@]}"; do
    rename_item "commands" "$name" "cm" "file"
  done

  # Runbooks (flat files)
  for name in "${RUNBOOKS[@]}"; do
    rename_item "runbooks" "$name" "rb" "file"
  done

  # Step 4: Patch internal references
  echo ""
  patch_references

  # Step 5: Rename sync state file
  echo ""
  info "Checking sync state file..."
  rename_sync_state

  # Step 6: Summary
  print_summary
}

main "$@"
