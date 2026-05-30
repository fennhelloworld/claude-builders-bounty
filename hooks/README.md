# Pre-Tool-Use Hook: Block Destructive Bash Commands

A Claude Code pre-tool-use hook that intercepts and blocks dangerous bash commands before they are executed.

## Features

- **Pattern-based blocking**: Detects and blocks destructive commands including:
  - rm -rf on non-standard paths (allows safe targets like node_modules, dist, build)
  - DROP TABLE - destroys entire database tables
  - TRUNCATE TABLE - removes all rows without individual logging
  - DELETE FROM without a WHERE clause - deletes ALL rows
  - git push --force / git push -f - overwrites remote history
  - git push --force-with-lease - force push variant
  - Fork bombs - denial of service patterns
  - chmod 000 on root paths - locks out access
  - dd writing to block devices - destroys raw disk data

- **Structured logging**: Every blocked attempt is logged to ~/.claude/hooks/blocked.log with:
  - ISO 8601 timestamp
  - Attempted command
  - Project path
  - Block reason

- **Clear feedback**: Returns a structured JSON response explaining why the command was blocked

## Installation

cp hooks/pre-tool-use-block-destructive.sh ~/.claude/hooks/pre-tool-use.sh && chmod +x ~/.claude/hooks/pre-tool-use.sh

That is it - 2 commands (chained with &&).

## How It Works

1. Claude Code invokes the hook via stdin with a JSON payload describing the tool use event
2. The hook parses the tool name and command from the JSON
3. If the tool is Bash, the command is checked against dangerous pattern regexes
4. Special logic handles DELETE FROM without WHERE and rm -rf with safe-target whitelisting
5. Blocked commands return {decision:block, reason:...} JSON - Claude Code respects this
6. Allowed commands pass through with exit code 0

## Log Format

Blocked attempts are appended as JSON lines to ~/.claude/hooks/blocked.log:

Example log entry:
  timestamp, command, project_path, reason fields in JSON format

## Testing

Run the included test script to verify all patterns are correctly detected:

  bash hooks/test-hook.sh

## Safe Target Whitelist

rm -rf is allowed on these commonly-safe build artifact directories:
- node_modules, dist, build, .cache, .next, .nuxt
- __pycache__, .tox, .eggs, target, out
- bin/Debug, bin/Release, coverage, .tmp, .temp

To add more safe targets, edit the SAFE_TARGETS regex in the script.

## License

MIT
