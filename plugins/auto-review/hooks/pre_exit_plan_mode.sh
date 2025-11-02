#!/bin/bash

# Read JSON input from stdin
INPUT=$(cat)

# Extract session_id
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Exit if we can't extract required fields
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# Check if review is required
FLAG_FILE="/tmp/$SESSION_ID/.auto_review_required"

if [ -f "$FLAG_FILE" ]; then
  # Remove the flag file
  rm -f "$FLAG_FILE"

  # Print the review request message to stderr (exit code 2 will block and show this to Claude)
  cat >&2 <<'EOF'
The plan requires review. Please run the tool 'mcp__plugin_auto-review_auto-review__review_plan' with these parameters:
- plan: '<summarize the plan steps clearly>'
- user_purpose: '<the user's stated goal or purpose>'
- context: '<technology stack, constraints, project type, any relevant background>'

After reviewing the feedback, you may revise the plan if needed, then present it again.
EOF

  exit 2
fi

# No review required, allow the tool call
# Create implementation review flag to signal that implementation will happen
mkdir -p "/tmp/$SESSION_ID"
touch "/tmp/$SESSION_ID/.impl_review_required"

exit 0
