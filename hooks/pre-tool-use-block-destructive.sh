#!/usr/bin/env bash
# =============================================================================
# Claude Code Pre-Tool-Use Hook: Block Destructive Bash Commands
# Bounty: claude-builders-bounty #3
# =============================================================================
# This hook intercepts bash commands before execution and blocks dangerous
# patterns that could cause irreversible damage to the project or data.
#
# Installation:
#   cp hooks/pre-tool-use-block-destructive.sh ~/.claude/hooks/pre-tool-use.sh
#   chmod +x ~/.claude/hooks/pre-tool-use.sh
#
# Claude Code hooks documentation: https://docs.anthropic.com/claude-code/hooks
# =============================================================================

set -euo pipefail

# --- Configuration ---
LOG_DIR="$HOME/.claude/hooks"
LOG_FILE="$LOG_DIR/blocked.log"
PROJECT_PATH="${PROJECT_PATH:-$(pwd)}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# --- Read input from stdin (Claude Code passes tool-use event as JSON) ---
INPUT=$(cat)

# Extract the tool name from the JSON input
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# Only intercept Bash tool calls
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# Extract the command from the tool input
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tool_input = data.get('tool_input', {})
    print(tool_input.get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# If no command extracted, allow through
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# --- Define dangerous patterns ---
# Format: "regex_pattern|block_reason"
DANGEROUS_PATTERNS=(
    "rm\s+-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*\s+/|Recursive force delete targeting root/absolute paths — irreversibly removes directories"
    "rm\s+-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*\s+/|Recursive force delete targeting root/absolute paths — irreversibly removes directories"
    "rm\s+--recursive\s+--force\s+/|Recursive force delete targeting root/absolute paths"
    "rm\s+--force\s+--recursive\s+/|Recursive force delete targeting root/absolute paths"
    "DROP\s+TABLE|DROP TABLE — destroys entire database tables and all their data permanently"
    "TRUNCATE\s+(TABLE\s+)?\w+|TRUNCATE — removes all rows from a table without individual row logging"
    "git\s+push\s+(-[a-zA-Z]+\s+)?--force(\s.*)?|git push --force — overwrites remote history, can lose others' commits"
    "git\s+push\s+-f(\s.*)?|git push -f — overwrites remote history, can lose others' commits"
    "git\s+push\s+--force-with-lease(\s.*)?|git push --force-with-lease — force push variant that can still overwrite commits"
    ":\(\)\{\s*:\|:\&\s*\};\s*:|Fork bomb — denial of service that exhausts system process/resources"
    "chmod\s+(-[a-zA-Z]+\s+)?000\s+/|chmod 000 on root path — locks out all access to critical directories"
    "dd\s+if=.*of=/dev/[a-z]+|Writing directly to block device via dd — can destroy raw disk data"
)

# --- Check command against patterns ---
BLOCKED=false
BLOCK_REASON=""

for PATTERN_REASON in "${DANGEROUS_PATTERNS[@]}"; do
    PATTERN="${PATTERN_REASON%%|*}"
    REASON="${PATTERN_REASON#*|}"

    if echo "$COMMAND" | grep -qPi "$PATTERN"; then
        BLOCKED=true
        BLOCK_REASON="$REASON"
        break
    fi
done

# --- Special check: DELETE FROM without WHERE clause ---
if echo "$COMMAND" | grep -qiP "DELETE\s+FROM"; then
    if ! echo "$COMMAND" | grep -qiP "WHERE\s+"; then
        BLOCKED=true
        BLOCK_REASON="DELETE FROM without WHERE clause — deletes ALL rows from a table"
    fi
fi

# --- Special check: rm -rf on any path (not just absolute) ---
if echo "$COMMAND" | grep -qiP "rm\s+(-\w*r\w*f\w*|-\w*f\w*r\w*)\s+\S+"; then
    # Block rm -rf unless it targets specific safe patterns (like node_modules, dist, build, .cache)
    TARGET=$(echo "$COMMAND" | grep -oiP "rm\s+(-\w*r\w*f\w*|-\w*f\w*r\w*)\s+\K\S+" | head -1)
    SAFE_TARGETS="(node_modules|dist|build|\.cache|\.next|\.nuxt|__pycache__|\.tox|\.eggs|target|out|bin/Debug|bin/Release|coverage|\.tmp|\.temp)"
    if [[ -n "$TARGET" ]] && ! echo "$TARGET" | grep -qiP "$SAFE_TARGETS"; then
        BLOCKED=true
        BLOCK_REASON="rm -rf on '$TARGET' — recursive force delete on non-standard target. Use safer alternatives or verify the path"
    fi
fi

# --- Handle blocked command ---
if [[ "$BLOCKED" == true ]]; then
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Log the blocked attempt as JSON for structured parsing
    LOG_ENTRY=$(printf '{"timestamp":"%s","command":"%s","project_path":"%s","reason":"%s"}\n' \
        "$TIMESTAMP" \
        "$(echo "$COMMAND" | sed 's/"/\\"/g')" \
        "$(echo "$PROJECT_PATH" | sed 's/"/\\"/g')" \
        "$(echo "$BLOCK_REASON" | sed 's/"/\\"/g')")
    echo "$LOG_ENTRY" >> "$LOG_FILE"

    # Output structured response for Claude Code hook protocol
    # Returns JSON with decision=block and human-readable reason
    REASON_ESCAPED=$(echo "$BLOCK_REASON" | sed 's/"/\\"/g')
    COMMAND_ESCAPED=$(echo "$COMMAND" | sed 's/"/\\"/g')
    cat << JSONEOF
{"decision":"block","reason":"Command blocked by security hook: $REASON_ESCAPED. Attempted command: $COMMAND_ESCAPED. If this is a false positive, modify the command or adjust hook configuration. Blocked attempt logged to $LOG_FILE"}
JSONEOF
    exit 0
fi

# --- Allow the command through ---
exit 0
