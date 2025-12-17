#!/usr/bin/env bash

# Aerospace workspace indicator plugin with DEBUG logging
# Usage: aerospace.sh <workspace_id>

# Enable logging
LOG_FILE="/tmp/sketchybar-aerospace-debug.log"
echo "=== $(date) ===" >> "$LOG_FILE"
echo "Called with workspace_id: $1" >> "$LOG_FILE"
echo "NAME env var: $NAME" >> "$LOG_FILE"
echo "FOCUSED_WORKSPACE env var: $FOCUSED_WORKSPACE" >> "$LOG_FILE"

WORKSPACE_ID="$1"

# Get current focused workspace from environment variable (passed by aerospace)
# or fallback to querying aerospace directly
if [ -z "$FOCUSED_WORKSPACE" ]; then
    FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null)
    echo "FOCUSED_WORKSPACE was empty, queried aerospace: $FOCUSED" >> "$LOG_FILE"
else
    FOCUSED="$FOCUSED_WORKSPACE"
    echo "Using FOCUSED_WORKSPACE from env: $FOCUSED" >> "$LOG_FILE"
fi

# Colors
BLUE=0xff8aadf4
BLACK=0xff181926
WHITE=0xffcad3f5
TRANSPARENT=0x00000000

echo "Comparing: '$WORKSPACE_ID' == '$FOCUSED'" >> "$LOG_FILE"

if [ "$WORKSPACE_ID" = "$FOCUSED" ]; then
    # Highlight focused workspace
    echo "MATCH! Highlighting workspace $WORKSPACE_ID" >> "$LOG_FILE"
    sketchybar --set $NAME \
        background.color=$BLUE \
        icon.color=$BLACK
else
    # Normal workspace
    echo "NO MATCH. Unhighlighting workspace $WORKSPACE_ID" >> "$LOG_FILE"
    sketchybar --set $NAME \
        background.color=$TRANSPARENT \
        icon.color=$WHITE
fi

echo "Done." >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
