#!/usr/bin/env bash
# PreToolUse(Bash) hook: stop `git commit` when a staged file is >= 2 MB.
# Forces explicit approval so large assets get compressed first.

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"

# Only act on git commit commands; let everything else through.
case "$cmd" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

LIMIT=2097152  # 2 MB in bytes
big=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  size="$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)"
  if [ "$size" -ge "$LIMIT" ]; then
    mb="$(awk "BEGIN{printf \"%.1f\", $size/1048576}")"
    big="${big}  - ${f} (${mb} MB)"$'\n'
  fi
done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)

if [ -n "$big" ]; then
  reason="Commit paused — these staged files are >= 2 MB:
${big}
Compress each below 2 MB first (re-export images as optimized JPG/PNG, downscale oversized assets). Only commit a large file as-is if the user has explicitly approved it."
  jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
fi
exit 0
