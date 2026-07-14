#!/usr/bin/env bash
# =============================================================================
# Codex Segregation of Duty Tracker — Global Hook
# Enforces: Codex review on all changes + Milestone/Type compliance
# =============================================================================

TRACK_DIR="/tmp/claude-codex-sod"
mkdir -p "$TRACK_DIR" 2>/dev/null || true

TRACK_FILE="${TRACK_DIR}/changed_files.log"
REVIEW_FILE="${TRACK_DIR}/reviewed_files.log"

EVENT="${1:-unknown}"

case "$EVENT" in
    SESSION_START)
        : > "$TRACK_FILE" 2>/dev/null || true
        : > "$REVIEW_FILE" 2>/dev/null || true
        cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"ABSOLUTE MANDATORY RULES — VIOLATION IS FORBIDDEN:\n\n== SEGREGATION OF DUTY ==\n1. Team Lead NEVER edits files directly. Use /c-bpm-cm-openissues-team ALWAYS.\n2. The reviewer is invoked by the TEAM LEAD ONLY, and never by a teammate. If you were spawned as a teammate, you have no shell and no reviewer: write the code, report honestly, and let the Lead verify. A teammate that claims a review verdict is fabricating one.\n3. The reviewer is the PRIMARY review authority. Team Lead approves alone is FORBIDDEN.\n4. Every file change is reviewed by the Team Lead before it lands.\n5. A teammate report is NARRATIVE, NEVER STATE. Only a Lead-posted GATE comment carrying a Lead-generated nonce advances a milestone.\n6. Post ALL review results as GitHub Issue comments.\n7. Use docker exec (not docker run) for container commands.\n\n== MILESTONE + TYPE (c-bpm-sk-milestone-type) ==\n8. EVERY issue MUST have exactly ONE milestone and ONE type label (bug or enhancement).\n9. Run /c-bpm-cm-openissues-list before any issue work to verify compliance.\n10. Update milestones at EVERY phase transition.\n11. DONE is HUMAN-ONLY — agents NEVER set DONE.\n\nTHESE RULES ARE NON-NEGOTIABLE."}}
EOF
        ;;

    POST_EDIT)
        INPUT="$(cat 2>/dev/null || echo '{}')"
        FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // "unknown"' 2>/dev/null || echo 'unknown')"
        echo "$FILE_PATH" >> "$TRACK_FILE" 2>/dev/null || true
        UNREVIEWED="$(sort -u "$TRACK_FILE" 2>/dev/null | wc -l)"
        REVIEWED="$(sort -u "$REVIEW_FILE" 2>/dev/null | wc -l)"
        PENDING=$((UNREVIEWED - REVIEWED))
        test "$PENDING" -lt 0 && PENDING=0
        # Telemetry only. This text is injected into EVERY agent, including restricted
        # teammates that must never invoke the reviewer (#101). It therefore states a
        # fact and issues no instruction — the Team Lead is the sole gate of record.
        printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"FILE CHANGED: %s — %d file(s) pending Team Lead review."}}\n' "$FILE_PATH" "$PENDING"
        ;;

    POST_BASH)
        INPUT="$(cat 2>/dev/null || echo '{}')"
        CMD="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo '')"
        if echo "$CMD" | grep -q "codex exec" 2>/dev/null; then
            cat "$TRACK_FILE" >> "$REVIEW_FILE" 2>/dev/null || true
        fi
        echo '{}'
        ;;

    STOP)
        if [ -f "$TRACK_FILE" ]; then
            CHANGED="$(sort -u "$TRACK_FILE" 2>/dev/null | wc -l)"
            REVIEWED="$(sort -u "$REVIEW_FILE" 2>/dev/null | wc -l)"
            PENDING=$((CHANGED - REVIEWED))
            test "$PENDING" -lt 0 && PENDING=0
            if [ "$PENDING" -gt 0 ]; then
                FILES="$(comm -23 <(sort -u "$TRACK_FILE") <(sort -u "$REVIEW_FILE") 2>/dev/null | tr '\n' ' ')"
                printf '{"systemMessage":"WARNING: %d file(s) changed without Codex review: %s"}\n' "$PENDING" "$FILES"
            else
                echo '{"systemMessage":"All changes Codex-reviewed. SoD compliant."}'
            fi
            rm -rf "$TRACK_DIR" 2>/dev/null || true
        else
            echo '{}'
        fi
        ;;

    *)
        echo '{}' ;;
esac
exit 0
