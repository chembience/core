#!/usr/bin/env bash
# Claude Code PostToolUse hook (Edit|Write): lint an edited shell script.
#
# Reads the hook JSON from stdin. If the edited file is a shell script (*.sh or
# a bash/sh shebang), runs `bash -n` and, when installed, ShellCheck with the
# CI settings. Findings are printed to stderr with exit code 2 so the agent sees
# and fixes them; every other file passes silently with exit code 0.
set -uo pipefail

file="$(python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
inp = data.get("tool_input") or {}
resp = data.get("tool_response") or {}
print(inp.get("file_path") or resp.get("filePath") or "")
')" || exit 0

[[ -n "$file" && -f "$file" ]] || exit 0
case "$file" in
  */test-builds/*|*/.git/*) exit 0 ;;
esac
if [[ "$file" != *.sh ]] && ! head -n 1 "$file" | grep -qE '^#!.*\b(ba)?sh\b'; then
  exit 0
fi

if ! syntax="$(bash -n "$file" 2>&1)"; then
  printf 'bash -n found syntax errors in %s:\n%s\n' "$file" "$syntax" >&2
  exit 2
fi
if command -v shellcheck >/dev/null 2>&1; then
  if ! findings="$(shellcheck -S warning -e SC1091 "$file" 2>&1)"; then
    printf 'ShellCheck (CI settings) found issues in %s:\n%s\n' "$file" "$findings" >&2
    exit 2
  fi
fi
exit 0
