#!/bin/bash

# Read JSON input from stdin
INPUT=$(cat)

# Extract session_id
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Check if implementation review flag exists
REVIEW_FLAG="/tmp/$SESSION_ID/.impl_review_required"

if [ -f "$REVIEW_FLAG" ]; then
  # Delete the flag and block with review prompt
  rm -f "$REVIEW_FLAG"
  cat <<'EOF'
{
  "decision": "block",
  "reason": "Implementation review required.\n\nAnalyze what you accomplished:\n- Did you make SIGNIFICANT code changes (new features, refactoring, bug fixes)?\n- Do the changes warrant critical review for correctness and quality?\n- Skip if: only trivial changes (typos, comments, formatting), no code written, or already reviewed\n\nIf significant implementation occurred, please run the 'mcp__plugin_auto-review_auto-review__review_impl' tool with:\n- plan: '<the original plan you were implementing>'\n- impl_detail: '<summary of what you implemented: files changed, functions added, key logic>'\n- context: '<technology stack, coding standards, architecture patterns, dependencies>'\n\nAfter reviewing the feedback, address any issues found before stopping."
}
EOF
  exit 0
fi

# No flag, approve stopping
cat <<'EOF'
{
  "decision": "approve"
}
EOF
exit 0