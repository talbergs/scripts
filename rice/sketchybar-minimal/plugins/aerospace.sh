#!/usr/bin/env bash

# Aerospace workspace indicator plugin
# Usage: aerospace.sh <workspace_id>

# Debug logging (remove these lines once working)
LOG_FILE="/tmp/sketchybar-aerospace.log"
echo "=== $(date) === workspace_id=$1 NAME=$NAME FOCUSED_WORKSPACE=$FOCUSED_WORKSPACE" >> "$LOG_FILE"

WORKSPACE_ID="$1"

# Get current focused workspace from environment variable (passed by aerospace)
# or fallback to querying aerospace directly
if [ -z "$FOCUSED_WORKSPACE" ]; then
    FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null)
else
    FOCUSED="$FOCUSED_WORKSPACE"
fi

# Colors
BLUE=0xff8aadf4
BLACK=0xff181926
WHITE=0xffcad3f5
TRANSPARENT=0x00000000

if [ "$WORKSPACE_ID" = "$FOCUSED" ]; then
    # Highlight focused workspace
    echo "  -> Highlighting $WORKSPACE_ID" >> "$LOG_FILE"
    sketchybar --set $NAME \
        background.color=$BLUE \
        icon.color=$BLACK
else
    # Normal workspace
    echo "  -> Unhighlighting $WORKSPACE_ID" >> "$LOG_FILE"
    sketchybar --set $NAME \
        background.color=$TRANSPARENT \
        icon.color=$WHITE
fi
