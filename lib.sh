#!/usr/bin/env bash
#
# lib.sh - Shared functions for bcgasl scripts
#
# Source this file in scripts:
#   source "$(dirname "$0")/lib.sh"
#
# Requires: VERBOSE variable to be set (0 or 1) before calling log_verbose

# Current version
BCGASL_VERSION="1.0.1"

# Naming convention: c-{ORG_PREFIX}-{type}-{name}
# shellcheck disable=SC2034
ITEM_PREFIX="c"
# shellcheck disable=SC2034
ORG_PREFIX="bpm"
# Type prefixes for glob patterns
# shellcheck disable=SC2034
SK_PREFIX="${ITEM_PREFIX}-${ORG_PREFIX}-sk"  # c-bpm-sk
# shellcheck disable=SC2034
CM_PREFIX="${ITEM_PREFIX}-${ORG_PREFIX}-cm"  # c-bpm-cm
# shellcheck disable=SC2034
AG_PREFIX="${ITEM_PREFIX}-${ORG_PREFIX}-ag"  # c-bpm-ag
# shellcheck disable=SC2034
RB_PREFIX="${ITEM_PREFIX}-${ORG_PREFIX}-rb"  # c-bpm-rb

# Map category name to its type prefix
# Usage: prefix=$(get_category_prefix "skills")
get_category_prefix() {
  case "$1" in
    skills)   echo "$SK_PREFIX" ;;
    commands) echo "$CM_PREFIX" ;;
    agents)   echo "$AG_PREFIX" ;;
    runbooks) echo "$RB_PREFIX" ;;
  esac
}

# Trusted domains for downloads (security: only allow known hosts)
TRUSTED_DOMAINS=("github.com" "raw.githubusercontent.com")

# Repository URLs (exported for use by sourcing scripts)
# shellcheck disable=SC2034
REPO_TARBALL="https://github.com/BPMspaceUG/bpm-claude-global-agent-skill-library/archive/refs/tags/v${BCGASL_VERSION}.tar.gz"
# shellcheck disable=SC2034
N8N_TARBALL="https://github.com/czlonkowski/n8n-skills/archive/main.tar.gz"
# shellcheck disable=SC2034
BCGASL_URL="https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/v${BCGASL_VERSION}/bcgasl"

# Checksums file URL
# shellcheck disable=SC2034
CHECKSUMS_URL="https://raw.githubusercontent.com/BPMspaceUG/bpm-claude-global-agent-skill-library/main/checksums.sha256"

# Expected checksum for current version tarball
# shellcheck disable=SC2034
REPO_TARBALL_CHECKSUM="babc86aa3d8e8fdf65006371b54f61166abe72144d818ba6263e803c3e7e9546"

# Extracted directory name for the tarball
# shellcheck disable=SC2034
EXTRACTED_DIR_NAME="bpm-claude-global-agent-skill-library-${BCGASL_VERSION}"

# Security: Validate URL against trusted domains
# Usage: validate_url "https://example.com/file"
# Returns: 0 if valid, 1 if invalid
validate_url() {
  local url="$1"
  local host

  # Validate URL is not empty
  if [[ -z "$url" ]]; then
    echo "ERROR: Empty URL provided" >&2
    return 1
  fi

  # Require HTTPS
  if [[ ! "$url" =~ ^https:// ]]; then
    echo "ERROR: URL must use HTTPS: $url" >&2
    return 1
  fi

  # Extract host from URL
  if [[ "$url" =~ ^https://([^/]+)/ ]]; then
    host="${BASH_REMATCH[1]}"
  else
    echo "ERROR: Invalid URL format: $url" >&2
    return 1
  fi

  # Check if host is in trusted domains
  for domain in "${TRUSTED_DOMAINS[@]}"; do
    if [[ "$host" == "$domain" ]]; then
      return 0
    fi
  done

  echo "ERROR: Untrusted domain '$host' in URL: $url" >&2
  echo "Trusted domains: ${TRUSTED_DOMAINS[*]}" >&2
  return 1
}

# Security: Validate path to prevent directory traversal
# Usage: validated_path=$(validate_path "/some/path")
# Returns: validated path or exits with error
# Note: This validates but does not sanitize - it rejects unsafe paths
validate_path() {
  local path="$1"

  # Check for empty path
  if [[ -z "$path" ]]; then
    echo "ERROR: Empty path provided" >&2
    return 1
  fi

  # Reject directory traversal attempts
  if [[ "$path" == *".."* ]]; then
    echo "ERROR: Path contains '..' (directory traversal): $path" >&2
    return 1
  fi

  # Check for null bytes (common injection technique)
  if [[ "$path" == *$'\0'* ]]; then
    echo "ERROR: Path contains null bytes: $path" >&2
    return 1
  fi

  echo "$path"
}

# Alias for backward compatibility
sanitize_path() {
  validate_path "$@"
}

# Security: Validate filename to prevent injection
# Usage: validated=$(validate_filename "myfile.txt")
# Returns: validated filename or exits with error
# Note: This validates but does not sanitize - it rejects unsafe filenames
validate_filename() {
  local filename="$1"

  # Check for empty filename
  if [[ -z "$filename" ]]; then
    echo "ERROR: Empty filename provided" >&2
    return 1
  fi

  # Reject if contains path separators
  if [[ "$filename" == *"/"* ]] || [[ "$filename" == *"\\"* ]]; then
    echo "ERROR: Filename contains path separator: $filename" >&2
    return 1
  fi

  # Reject directory traversal
  if [[ "$filename" == ".." ]] || [[ "$filename" == "." ]]; then
    echo "ERROR: Invalid filename: $filename" >&2
    return 1
  fi

  # Reject filenames starting with dash (could be interpreted as options)
  if [[ "$filename" == -* ]]; then
    echo "ERROR: Filename cannot start with dash: $filename" >&2
    return 1
  fi

  echo "$filename"
}

# Alias for backward compatibility
sanitize_filename() {
  validate_filename "$@"
}

# Verbose logging helper
# Usage: log_verbose "message"
# Requires: VERBOSE variable to be set (0 or 1)
log_verbose() {
  if [[ "${VERBOSE:-0}" -eq 1 ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

# Compute SHA256 checksum of a file
# Usage: checksum=$(compute_sha256 "/path/to/file")
compute_sha256() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "ERROR: File not found for checksum: $file" >&2
    return 1
  fi

  # Use sha256sum (Linux) or shasum (macOS)
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | cut -d' ' -f1
  else
    echo "ERROR: No sha256sum or shasum command found" >&2
    return 1
  fi
}

# Verify file checksum against expected value
# Usage: verify_checksum "/path/to/file" "expected_sha256"
# Returns: 0 if match, 1 if mismatch
verify_checksum() {
  local file="$1"
  local expected="$2"

  local actual
  actual=$(compute_sha256 "$file") || return 1

  if [[ "$actual" == "$expected" ]]; then
    log_verbose "Checksum verified: $file"
    return 0
  else
    echo "ERROR: Checksum mismatch for $file" >&2
    echo "  Expected: $expected" >&2
    echo "  Actual:   $actual" >&2
    return 1
  fi
}

# Download and verify a file with optional checksum
# Usage: download_with_checksum "url" "/path/to/output" ["expected_sha256"]
# Returns: 0 on success, 1 on failure
download_with_checksum() {
  local url="$1"
  local output="$2"
  local expected_checksum="${3:-}"

  # Validate URL
  validate_url "$url" || return 1

  # Download
  log_verbose "Downloading: $url"
  if ! curl -fsSL "$url" -o "$output"; then
    echo "ERROR: Failed to download: $url" >&2
    return 1
  fi

  # Verify file exists and is not empty
  if [[ ! -s "$output" ]]; then
    echo "ERROR: Downloaded file is empty: $output" >&2
    rm -f "$output"
    return 1
  fi

  # Verify checksum if provided
  if [[ -n "$expected_checksum" ]]; then
    if ! verify_checksum "$output" "$expected_checksum"; then
      rm -f "$output"
      return 1
    fi
  fi

  return 0
}

# Load checksums from a checksums file
# Usage: load_checksums "/path/to/checksums.sha256"
# Sets: LOADED_CHECKSUMS associative array (filename -> checksum)
declare -A LOADED_CHECKSUMS
load_checksums() {
  local checksums_file="$1"
  LOADED_CHECKSUMS=()

  if [[ ! -f "$checksums_file" ]]; then
    log_verbose "No checksums file found: $checksums_file"
    return 0
  fi

  while IFS=' ' read -r checksum filename; do
    # Skip empty lines and comments
    [[ -z "$checksum" || "$checksum" == "#"* ]] && continue
    # Remove leading ./ or * from filename (sha256sum formats vary)
    filename="${filename#./}"
    filename="${filename#\*}"
    LOADED_CHECKSUMS["$filename"]="$checksum"
    log_verbose "Loaded checksum for $filename: $checksum"
  done < "$checksums_file"

  log_verbose "Loaded ${#LOADED_CHECKSUMS[@]} checksums"
  return 0
}

# Get checksum for a file from loaded checksums
# Usage: checksum=$(get_loaded_checksum "filename")
# Returns: checksum or empty string if not found
get_loaded_checksum() {
  local filename="$1"
  echo "${LOADED_CHECKSUMS[$filename]:-}"
}

# Determine the target directory for Claude configuration
# Usage: target=$(get_target_dir)
# Checks which directory Claude Code actively uses (by settings.json presence)
get_target_dir() {
  if [[ -f "$HOME/.claude/settings.json" ]]; then
    echo "$HOME/.claude"
  elif [[ -f "$HOME/.config/claude/settings.json" ]]; then
    echo "$HOME/.config/claude"
  elif [[ -d "$HOME/.claude" ]]; then
    echo "$HOME/.claude"
  elif [[ -d "$HOME/.config/claude" ]]; then
    echo "$HOME/.config/claude"
  else
    echo "$HOME/.claude"
  fi
}

# Create a secure temporary directory
# Usage: tmp_dir=$(create_secure_tmpdir)
# Caller is responsible for cleanup: trap 'rm -rf "$tmp_dir"' EXIT
create_secure_tmpdir() {
  local tmp_dir
  tmp_dir="$(mktemp -d)" || {
    echo "ERROR: Failed to create temporary directory" >&2
    return 1
  }

  # Ensure only owner can access
  chmod 700 "$tmp_dir" || {
    rm -rf "$tmp_dir"
    echo "ERROR: Failed to set permissions on temporary directory" >&2
    return 1
  }

  echo "$tmp_dir"
}

# Download file with validation
# Usage: download_file "https://url" "/path/to/output"
# Returns: 0 on success, 1 on failure
download_file() {
  local url="$1"
  local output="$2"

  # Validate URL
  validate_url "$url" || return 1

  # Download with curl
  log_verbose "Downloading: $url -> $output"
  if ! curl -fsSL "$url" -o "$output"; then
    echo "ERROR: Failed to download: $url" >&2
    return 1
  fi

  # Verify file was created and is not empty
  if [[ ! -s "$output" ]]; then
    echo "ERROR: Downloaded file is empty: $output" >&2
    rm -f "$output"
    return 1
  fi

  return 0
}

# Download and extract tarball with validation
# Usage: download_and_extract "https://url" "/path/to/tmpdir" "expected-dir-name"
# Returns: 0 on success, 1 on failure
download_and_extract() {
  local url="$1"
  local tmp_dir="$2"
  local expected_dir="$3"

  # Validate URL
  validate_url "$url" || return 1

  # Download and extract
  log_verbose "Downloading and extracting: $url"
  if ! curl -fsSL "$url" | tar -xz -C "$tmp_dir"; then
    echo "ERROR: Failed to download or extract: $url" >&2
    return 1
  fi

  # Validate extracted directory exists
  if [[ ! -d "$tmp_dir/$expected_dir" ]]; then
    echo "ERROR: Expected directory not found after extraction: $expected_dir" >&2
    return 1
  fi

  log_verbose "Extracted to: $tmp_dir/$expected_dir"
  return 0
}

# Validate directory name is in allowed list
# Usage: validate_dir_name "agents" agents skills runbooks templates
# Returns: 0 if valid, 1 if invalid
validate_dir_name() {
  local dir="$1"
  shift
  local allowed=("$@")

  # Check for empty
  if [[ -z "$dir" ]]; then
    echo "ERROR: Empty directory name" >&2
    return 1
  fi

  # Check against allowed list
  for allowed_dir in "${allowed[@]}"; do
    if [[ "$dir" == "$allowed_dir" ]]; then
      return 0
    fi
  done

  echo "ERROR: Directory '$dir' not in allowed list: ${allowed[*]}" >&2
  return 1
}

# Validate extracted tarball directory name matches expected pattern
# Usage: validate_extracted_dir "repo-name-main" "repo-name"
# Returns: 0 if valid, 1 if invalid
validate_extracted_dir() {
  local actual="$1"
  local expected_prefix="$2"

  # Check for directory traversal or absolute paths
  if [[ "$actual" == *".."* ]] || [[ "$actual" == /* ]]; then
    echo "ERROR: Invalid extracted directory name: $actual" >&2
    return 1
  fi

  # Check it starts with expected prefix
  if [[ ! "$actual" =~ ^${expected_prefix} ]]; then
    echo "ERROR: Extracted directory '$actual' does not match expected pattern '$expected_prefix*'" >&2
    return 1
  fi

  return 0
}

# Write host inventory to my/hosts/<HOSTNAME>/
# Records which c-bpm items are installed on this host
# Usage: write_host_inventory "/path/to/repo" "/path/to/claude-dir"
write_host_inventory() {
  local repo_dir="$1"
  local claude_dir="$2"
  local host_name
  host_name="$(hostname)"
  local host_dir="$repo_dir/my/hosts/$host_name"

  mkdir -p "$host_dir"

  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  # Skills (directories)
  {
    echo "# Host: $host_name"
    echo "# Updated: $ts"
    echo "# Category: skills"
    echo "#"
    if [[ -d "$claude_dir/skills" ]]; then
      ls -1 "$claude_dir/skills/" 2>/dev/null | grep "^${ITEM_PREFIX}-${ORG_PREFIX}-" | sort
    fi
  } > "$host_dir/skills.txt"

  # Commands (files)
  {
    echo "# Host: $host_name"
    echo "# Updated: $ts"
    echo "# Category: commands"
    echo "#"
    if [[ -d "$claude_dir/commands" ]]; then
      ls -1 "$claude_dir/commands/" 2>/dev/null | grep "^${ITEM_PREFIX}-${ORG_PREFIX}-" | sort
    fi
  } > "$host_dir/commands.txt"

  # Agents (files)
  {
    echo "# Host: $host_name"
    echo "# Updated: $ts"
    echo "# Category: agents"
    echo "#"
    if [[ -d "$claude_dir/agents" ]]; then
      ls -1 "$claude_dir/agents/" 2>/dev/null | grep "^${ITEM_PREFIX}-${ORG_PREFIX}-" | sort
    fi
  } > "$host_dir/agents.txt"

  log_verbose "Host inventory written to $host_dir"
}

# --- Sync state management (shared between pull/push) ---
# Requires: DRY_RUN variable to be set (0 or 1) before calling save_sync_state

declare -A SYNC_STATE

# Compute a deterministic hash for a file or directory
# Usage: hash=$(compute_item_hash "/path/to/item")
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

# Load sync state from file into SYNC_STATE associative array
# Usage: load_sync_state "/path/to/sync-file"
load_sync_state() {
  local sync_file="$1"
  SYNC_STATE=()
  [[ -f "$sync_file" ]] || return 0
  while IFS=' ' read -r hash key; do
    [[ -z "$hash" || "$hash" == "#"* ]] && continue
    SYNC_STATE["$key"]="$hash"
  done < "$sync_file"
  log_verbose "Loaded ${#SYNC_STATE[@]} sync baselines"
}

# Get the stored hash for a sync key
# Usage: hash=$(get_sync_hash "category/item_name")
get_sync_hash() {
  echo "${SYNC_STATE[$1]:-}"
}

# Set the hash for a sync key
# Usage: set_sync_hash "category/item_name" "hash_value"
set_sync_hash() {
  SYNC_STATE["$1"]="$2"
}

# Save sync state to file (skips if DRY_RUN=1)
# Usage: save_sync_state "/path/to/sync-file"
# Requires: DRY_RUN variable
save_sync_state() {
  local sync_file="$1"
  [[ "${DRY_RUN:-0}" -eq 1 ]] && return 0
  : > "$sync_file"
  for key in $(echo "${!SYNC_STATE[@]}" | tr ' ' '\n' | sort); do
    echo "${SYNC_STATE[$key]} $key" >> "$sync_file"
  done
  log_verbose "Saved ${#SYNC_STATE[@]} sync baselines"
}

# Prune sync state entries where the source item no longer exists
# Usage: prune_sync_state "/path/to/source/dir"
prune_sync_state() {
  local source_dir="$1"
  local pruned=0
  for key in "${!SYNC_STATE[@]}"; do
    local category="${key%%/*}"
    local item_name="${key#*/}"
    local source_path="$source_dir/$key"
    # Skills are directories, others are files
    if [[ "$category" == "skills" ]]; then
      [[ -d "$source_path" ]] && continue
    else
      [[ -f "$source_path" ]] && continue
    fi
    unset 'SYNC_STATE[$key]'
    log_verbose "Pruned stale sync entry: $key"
    ((pruned++)) || true
  done
  [[ "$pruned" -gt 0 ]] && echo "Pruned $pruned stale sync entries" || true
}

# --- End sync state ---

# --- Skill rules generation ---

# Parse YAML frontmatter value from a SKILL.md file
# Usage: value=$(parse_frontmatter_field "/path/to/SKILL.md" "description")
parse_frontmatter_field() {
  local file="$1"
  local field="$2"
  local in_frontmatter=0
  local value=""

  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if [[ "$in_frontmatter" -eq 0 ]]; then
        in_frontmatter=1
        continue
      else
        break
      fi
    fi
    if [[ "$in_frontmatter" -eq 1 ]]; then
      # Match "field: value" or "field: >", handling optional quotes
      if [[ "$line" =~ ^${field}:\ *(.*) ]]; then
        value="${BASH_REMATCH[1]}"
        # Strip surrounding quotes
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        # If it's a YAML multiline indicator (>), read continuation lines
        if [[ "$value" == ">" || "$value" == "|" ]]; then
          value=""
          while IFS= read -r cont_line; do
            [[ "$cont_line" == "---" ]] && break
            # Stop at next field (non-indented line with colon)
            if [[ "$cont_line" =~ ^[a-zA-Z] ]]; then
              break
            fi
            # Strip leading whitespace and append
            cont_line="${cont_line#"${cont_line%%[![:space:]]*}"}"
            if [[ -n "$value" ]]; then
              value="$value $cont_line"
            else
              value="$cont_line"
            fi
          done
        fi
      fi
    fi
  done < "$file"

  echo "$value"
}

# Generate or update skill-rules.json from installed c-bpm skills and commands
# Usage: generate_skill_rules_json "/path/to/claude-dir"
# Scans $claude_dir/skills/c-bpm-sk-*/SKILL.md and $claude_dir/commands/c-bpm-cm-*.md
# Writes $claude_dir/skills/skill-rules.json
# All JSON serialization AND keyword generation is handled by Python to prevent
# injection and encoding bugs.
generate_skill_rules_json() {
  local claude_dir="$1"
  local skills_dir="$claude_dir/skills"
  local commands_dir="$claude_dir/commands"
  local rules_file="$skills_dir/skill-rules.json"
  local skill_count=0
  local command_count=0
  local org_prefix="${ORG_PREFIX}"

  [[ -d "$skills_dir" ]] || return 0

  # Collect item data as tab-separated lines: name\tdescription\titem_type\tenforcement\tintentPatterns
  # item_type is "skill" or "command" (used by Python for prefix stripping)
  local item_data=""

  # Scan skills: c-bpm-sk-*/SKILL.md
  for skill_dir in "$skills_dir"/"${ITEM_PREFIX}-${org_prefix}-sk"-*/; do
    [[ -d "$skill_dir" ]] || continue
    local skill_md="$skill_dir/SKILL.md"
    [[ -f "$skill_md" ]] || continue

    local skill_name
    skill_name=$(basename "$skill_dir")

    local description
    description=$(parse_frontmatter_field "$skill_md" "description")
    [[ -z "$description" ]] && description="Skill: $skill_name"

    local enforcement
    enforcement=$(parse_frontmatter_field "$skill_md" "enforcement")
    [[ -z "$enforcement" ]] && enforcement=""

    local intent_patterns
    intent_patterns=$(parse_frontmatter_field "$skill_md" "intentPatterns")
    [[ -z "$intent_patterns" ]] && intent_patterns=""

    item_data+="${skill_name}"$'\t'"${description}"$'\t'"skill"$'\t'"${enforcement}"$'\t'"${intent_patterns}"$'\n'
    ((skill_count++)) || true
  done

  # Scan commands: c-bpm-cm-*.md
  if [[ -d "$commands_dir" ]]; then
    for cmd_file in "$commands_dir"/"${ITEM_PREFIX}-${org_prefix}-cm"-*.md; do
      [[ -f "$cmd_file" ]] || continue

      local cmd_name
      cmd_name=$(basename "$cmd_file" .md)

      local description
      description=$(parse_frontmatter_field "$cmd_file" "description")
      [[ -z "$description" ]] && description="Command: $cmd_name"

      local enforcement
      enforcement=$(parse_frontmatter_field "$cmd_file" "enforcement")
      [[ -z "$enforcement" ]] && enforcement=""

      item_data+="${cmd_name}"$'\t'"${description}"$'\t'"command"$'\t'"${enforcement}"$'\t'$'\n'
      ((command_count++)) || true
    done
  fi

  local total_count=$((skill_count + command_count))
  if [[ "$total_count" -eq 0 ]]; then
    log_verbose "No c-bpm skills or commands found to register"
    return 0
  fi

  # Write item data to a temp file so Python can read it independently of stdin.
  local item_data_file
  item_data_file=$(mktemp) || {
    echo "ERROR: Failed to create temp file for item data" >&2
    return 1
  }
  # shellcheck disable=SC2064
  trap "rm -f '$item_data_file'" RETURN
  printf '%s' "$item_data" > "$item_data_file"

  # Python builds the complete JSON: reads existing rules file (preserving non-c-bpm
  # entries), generates keywords from name + description, outputs valid JSON.
  # All paths are passed as sys.argv (not interpolated into Python source).
  #   sys.argv[1] = rules_file path
  #   sys.argv[2] = org_prefix for filtering
  #   sys.argv[3] = item_data_file path
  local json_output
  json_output=$(python3 - "$rules_file" "$org_prefix" "$item_data_file" << 'PYEOF'
import json
import sys
import os
import re

rules_file = sys.argv[1]
org_prefix = sys.argv[2]
data_file = sys.argv[3]
cbpm_sk_prefix = f"c-{org_prefix}-sk-"
cbpm_cm_prefix = f"c-{org_prefix}-cm-"
cbpm_prefixes = (cbpm_sk_prefix, cbpm_cm_prefix)

def generate_keywords(name, description, item_type):
    """Generate keyword list from item name and description.

    Name-derived keywords: split slug on hyphens, keep words >= 3 chars,
    add spaced version and full name.

    Description-derived keywords: if description contains ' — ' (em-dash),
    take only text up to the first period, then split on commas to extract trigger phrases.
    """
    keywords = []

    # Strip the c-{org}-{type}- prefix to get the short slug
    if item_type == "skill":
        short_name = name[len(cbpm_sk_prefix):] if name.startswith(cbpm_sk_prefix) else name
    else:
        short_name = name[len(cbpm_cm_prefix):] if name.startswith(cbpm_cm_prefix) else name

    # Split short name on hyphens, keep words >= 3 chars
    parts = short_name.split("-")
    for part in parts:
        if len(part) >= 3:
            keywords.append(part)

    # Add spaced version of the short name
    spaced = short_name.replace("-", " ")
    keywords.append(spaced)

    # Add the full item name (for explicit invocation)
    keywords.append(name)

    # Extract trigger phrases from description after em-dash
    if " \u2014 " in description:
        after_dash = description.split(" \u2014 ", 1)[1]
        # Take only text up to the first period (ignore explanatory sentences)
        trigger_segment = after_dash.split(". ", 1)[0]
        phrases = trigger_segment.split(",")
        for phrase in phrases:
            phrase = phrase.strip()
            if phrase:
                keywords.append(phrase)

    return keywords

# Load preserved (non-c-bpm) entries from existing rules file
preserved = {}
if os.path.isfile(rules_file):
    try:
        with open(rules_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        skills = data.get("skills", {})
        preserved = {
            k: v for k, v in skills.items()
            if not any(k.startswith(p) for p in cbpm_prefixes)
        }
    except FileNotFoundError:
        pass
    except json.JSONDecodeError as exc:
        print(f"WARNING: Failed to parse existing {rules_file}: {exc}", file=sys.stderr)
    except OSError as exc:
        print(f"WARNING: Could not read {rules_file}: {exc}", file=sys.stderr)

# Parse new c-bpm entries from data file (tab-separated: name, description, item_type, enforcement, intentPatterns)
new_entries = {}
with open(data_file, "r", encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t", 4)
        if len(parts) < 3:
            continue
        name, description, item_type = parts[0], parts[1], parts[2]
        enforcement_raw = parts[3].strip() if len(parts) > 3 else ""
        intent_patterns_raw = parts[4].strip() if len(parts) > 4 else ""

        # Enforcement: use frontmatter value if valid, else default "suggest"
        if enforcement_raw in ("block", "suggest"):
            enforcement = enforcement_raw
        else:
            enforcement = "suggest"

        # Intent patterns: parse ;;-separated string into list
        intent_patterns = []
        if intent_patterns_raw:
            intent_patterns = [p.strip() for p in intent_patterns_raw.split(";;") if p.strip()]

        keywords = generate_keywords(name, description, item_type)
        entry = {
            "type": "domain",
            "enforcement": enforcement,
            "priority": "medium",
            "description": description,
            "promptTriggers": {
                "keywords": keywords
            }
        }
        if intent_patterns:
            entry["promptTriggers"]["intentPatterns"] = intent_patterns
        new_entries[name] = entry

# Merge: preserved entries first, then new c-bpm entries
all_skills = {}
all_skills.update(preserved)
all_skills.update(new_entries)

output = {
    "version": "1.0",
    "description": "Skill activation triggers for Claude Code. Auto-generated by c-bpm-cm-library-pull.",
    "skills": all_skills,
    "notes": {
        "auto_generated": "This file is auto-generated by c-bpm-cm-library-pull. Non-c-bpm entries are preserved on regeneration."
    }
}

print(json.dumps(output, indent=4))
PYEOF
  ) || {
    echo "ERROR: Failed to generate skill-rules.json via Python" >&2
    return 1
  }

  if [[ "${DRY_RUN:-0}" -eq 0 ]]; then
    printf '%s\n' "$json_output" > "$rules_file"
    log_verbose "Generated skill-rules.json with $skill_count skills + $command_count commands"
    echo "Registered $skill_count c-bpm skills + $command_count commands in skill-rules.json"
  else
    echo "[dry-run] Would register $skill_count c-bpm skills + $command_count commands in skill-rules.json"
  fi
}

# --- End skill rules generation ---

# Check if a command exists
# Usage: command_exists "curl"
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Ensure required commands are available
# Usage: require_commands "curl" "tar" "diff"
require_commands() {
  local missing=()
  for cmd in "$@"; do
    if ! command_exists "$cmd"; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Required commands not found: ${missing[*]}" >&2
    return 1
  fi
  return 0
}
