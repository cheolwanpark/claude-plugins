#!/bin/bash

# Read JSON input from stdin
INPUT=$(cat)

# Extract session_id and permission_mode
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PERMISSION_MODE=$(echo "$INPUT" | jq -r '.permission_mode // empty')

# Exit if we can't extract required fields
if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# If permission_mode is "plan", set the review required flag
if [ "$PERMISSION_MODE" = "plan" ]; then
  mkdir -p "/tmp/$SESSION_ID"
  touch "/tmp/$SESSION_ID/.auto_review_required"
fi

exit 0
