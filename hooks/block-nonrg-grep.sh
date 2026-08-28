#!/bin/bash
# PreToolUse/Bash guard: block grep -r, find -exec grep, and ugrep in favor of rg.
# See the using-rg skill / global CLAUDE.md "Command-line text search" mandate.
cmd=$(jq -r '.tool_input.command // empty')

matched=""
if printf '%s' "$cmd" | grep -Eq '(^|[;&|(]|[[:space:]])ugrep([[:space:]]|$)'; then
  matched=ugrep
elif printf '%s' "$cmd" | grep -Pq '\bgrep\b(?:(?![;&|]).)*(?:^|[[:space:]])(-[A-Za-z]*[rR][A-Za-z]*\b|--recursive\b)'; then
  matched=grep-r
elif printf '%s' "$cmd" | grep -Pq '\bfind\b(?:(?![;&|]).)*-exec(dir)?[[:space:]]+grep\b'; then
  matched=find-exec-grep
fi

if [ -n "$matched" ]; then
  jq -n --arg cmd "$cmd" --arg m "$matched" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("Blocked (\($m)): use rg (ripgrep) instead of grep -r / find -exec grep / ugrep — see the using-rg skill. Command: " + $cmd)}}'
else
  echo '{}'
fi
