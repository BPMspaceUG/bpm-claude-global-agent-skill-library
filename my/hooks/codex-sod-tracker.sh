#!/usr/bin/env bash
# =============================================================================
# Codex Segregation of Duty Tracker — repo-confined, per-session (#168, #86, #166)
# Telemetry only. Always exits 0. Tracks ONLY git-tracked code inside the CURRENT
# session's repo; everything outside the session repo (other repos, ~/.claude
# memory, /tmp scratch) is ignored by containment, and in-repo non-code
# (per-host inventory, MEMORY.md, untracked scratch) is ignored explicitly.
# Note: /tmp is NOT a blanket exclusion — a repo legitimately hosted under /tmp
# (e.g. the #162 throwaway gate worktree) still tracks its own git-tracked files;
# only paths OUTSIDE the session repo are dropped, which containment already does.
# =============================================================================

EVENT="${1:-unknown}"
# Bounded stdin read — never block. Real Claude Code hooks pipe JSON and close
# stdin (returns instantly on EOF); an invocation with no data falls back to {}
# after a short timeout instead of hanging on an open pipe (#171).
INPUT=''
IFS= read -r -d '' -t 2 INPUT 2>/dev/null || true
[ -n "$INPUT" ] || INPUT='{}'

SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null | tr -cd 'A-Za-z0-9_-')"
[ -n "$SESSION_ID" ] || SESSION_ID="nosession"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)"

TRACK_ROOT="/tmp/claude-codex-sod"
TRACK_DIR="${TRACK_ROOT}/${SESSION_ID}"
TRACK_FILE="${TRACK_DIR}/changed_files.log"

SESSION_REPO_ROOT="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$SESSION_REPO_ROOT" ]; then
  SESSION_REPO_ROOT="$(realpath -m -- "$SESSION_REPO_ROOT" 2>/dev/null || true)"
fi

is_trackable() {
  local p="$1" rp rel root="$SESSION_REPO_ROOT"
  [ -n "$p" ] && [ "$p" != "unknown" ] || return 1
  rp="$(realpath -m -- "$p" 2>/dev/null)" || return 1
  [ -n "$rp" ] || return 1
  [ -n "$root" ] || return 1
  case "${rp}/" in "${root}/"*) : ;; *) return 1 ;; esac
  case "$rp" in
    "$HOME"/.claude/*|"$HOME"/.config/claude/*) return 1 ;;
    */MEMORY.md) return 1 ;;
    */my/hosts/*/agents.txt|*/my/hosts/*/commands.txt|*/my/hosts/*/skills.txt|*/my/hosts/*/tools.yaml) return 1 ;;
  esac
  rel="${rp#"${root}/"}"
  [ "$rel" != "$rp" ] || return 1
  git -C "$root" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 && return 0
  git -C "$root" diff --cached --name-only -- "$rel" 2>/dev/null | grep -q . && return 0
  return 1
}

case "$EVENT" in
  SESSION_START)
    mkdir -p "$TRACK_DIR" 2>/dev/null || true
    : > "$TRACK_FILE" 2>/dev/null || true
    cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"ABSOLUTE MANDATORY RULES — VIOLATION IS FORBIDDEN:\n\n== SEGREGATION OF DUTY ==\n1. Team Lead NEVER edits files directly. Use /c-bpm-cm-openissues-team ALWAYS.\n2. The reviewer is invoked by the TEAM LEAD ONLY, and never by a teammate. If you were spawned as a teammate, you have no shell and no reviewer: write the code, report honestly, and let the Lead verify. A teammate that claims a review verdict is fabricating one.\n3. The reviewer is the PRIMARY review authority. Team Lead approves alone is FORBIDDEN.\n4. Every code change in a git-tracked repo is reviewed by the Team Lead at phase transitions.\n5. A teammate report is NARRATIVE, NEVER STATE. Only a Lead-posted GATE comment carrying a Lead-generated nonce advances a milestone.\n6. Post ALL review results as GitHub Issue comments.\n7. Use docker exec (not docker run) for container commands.\n\n== REPO CONFINEMENT (#166) ==\nA skill/agent acts ONLY within the current repo, even when installed centrally. The only permitted cross-repo actions are creating an Issue in another repo, or commenting on an Issue this session created there. Nothing else.\n\n== MILESTONE + TYPE (c-bpm-sk-milestone-type) ==\n8. EVERY issue MUST have exactly ONE milestone and ONE type label (bug or enhancement).\n9. Run /c-bpm-cm-openissues-list before any issue work to verify compliance.\n10. Update milestones at EVERY phase transition.\n11. DONE is HUMAN-ONLY — agents NEVER set DONE.\n\nTHESE RULES ARE NON-NEGOTIABLE."}}
JSON
    ;;

  POST_EDIT)
    FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // "unknown"' 2>/dev/null || echo 'unknown')"
    if is_trackable "$FILE_PATH"; then
      mkdir -p "$TRACK_DIR" 2>/dev/null || true
      realpath -m -- "$FILE_PATH" 2>/dev/null >> "$TRACK_FILE" || echo "$FILE_PATH" >> "$TRACK_FILE"
      COUNT="$(sort -u "$TRACK_FILE" 2>/dev/null | wc -l)"
      printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"FILE CHANGED: %s — %d file(s) changed this session (telemetry; the review gate is the Lead ## GATE comment)."}}\n' "$FILE_PATH" "$COUNT"
    else
      echo '{}'
    fi
    ;;

  POST_BASH)
    echo '{}'
    ;;

  STOP)
    if [ -f "$TRACK_FILE" ]; then
      COUNT="$(sort -u "$TRACK_FILE" 2>/dev/null | wc -l)"
      if [ "$COUNT" -gt 0 ]; then
        FILES="$(sort -u "$TRACK_FILE" 2>/dev/null | tr '\n' ' ')"
        printf '{"systemMessage":"SoD telemetry: %d file(s) changed this session: %s(review gate is the Lead ## GATE comment)."}\n' "$COUNT" "$FILES"
      else
        echo '{"systemMessage":"SoD telemetry: no tracked file changes this session."}'
      fi
    else
      echo '{}'
    fi
    rm -rf "$TRACK_DIR" 2>/dev/null || true
    ;;

  *)
    echo '{}' ;;
esac
exit 0
