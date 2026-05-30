#!/usr/bin/env bash
# Test script for pre-tool-use-block-destructive.sh
set -euo pipefail

HOOK_SCRIPT="$(dirname "$0")/pre-tool-use-block-destructive.sh"
PASS=0
FAIL=0

test_command() {
    local description="$1"
    local tool_name="$2"
    local command="$3"
    local expected_block="$4"

    local json_input
    if [[ "$tool_name" == "Bash" ]]; then
        json_input="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$command\"}}"
    else
        json_input="{\"tool_name\":\"$tool_name\",\"tool_input\":{}}"
    fi

    local result
    result=$(echo "$json_input" | bash "$HOOK_SCRIPT" 2>/dev/null || true)

    if [[ "$expected_block" == "block" ]]; then
        if echo "$result" | grep -q '"decision":"block"'; then
            PASS=$((PASS + 1))
            echo "  PASS: $description"
        else
            FAIL=$((FAIL + 1))
            echo "  FAIL: $description (expected block)"
        fi
    else
        if [[ -z "$result" ]] || ! echo "$result" | grep -q '"decision":"block"'; then
            PASS=$((PASS + 1))
            echo "  PASS: $description"
        else
            FAIL=$((FAIL + 1))
            echo "  FAIL: $description (expected allow)"
        fi
    fi
}

echo "=== Testing Pre-Tool-Use Hook ==="
echo ""
echo "--- Blocking Tests ---"
test_command "Block recursive force delete root" "Bash" "rm -rf /" "block"
test_command "Block recursive force delete var" "Bash" "rm -rfd /var/log" "block"
test_command "Block DROP TABLE" "Bash" "echo 'DROP TABLE users;'" "block"
test_command "Block TRUNCATE" "Bash" "echo 'TRUNCATE TABLE users;'" "block"
test_command "Block DELETE without WHERE" "Bash" "echo 'DELETE FROM users;'" "block"
test_command "Block force push" "Bash" "git push --force origin main" "block"
test_command "Block force push short" "Bash" "git push -f origin main" "block"
test_command "Block chmod 000 root" "Bash" "chmod 000 /" "block"
echo ""
echo "--- Allow Tests ---"
test_command "Allow ls" "Bash" "ls -la" "allow"
test_command "Allow git status" "Bash" "git status" "allow"
test_command "Allow npm install" "Bash" "npm install" "allow"
test_command "Allow safe rm node_modules" "Bash" "rm -rf node_modules" "allow"
test_command "Allow safe rm dist" "Bash" "rm -rf dist" "allow"
test_command "Allow DELETE with WHERE" "Bash" "echo 'DELETE FROM users WHERE id = 1;'" "allow"
test_command "Allow non-Bash tool" "Read" "" "allow"
echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
if [[ $FAIL -gt 0 ]]; then exit 1; else echo "All tests PASSED"; exit 0; fi
