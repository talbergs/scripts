#!/usr/bin/env bash

# Aerospace workspace indicator plugin
# Usage: aerospace.sh <workspace_id>

WORKSPACE_ID="$1"

# Get current focused workspace
FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null)

# Colors
BLUE=0xff8aadf4
BLACK=0xff181926
WHITE=0xffcad3f5
TRANSPARENT=0x00000000

if [ "$WORKSPACE_ID" = "$FOCUSED" ]; then
    # Highlight focused workspace
    sketchybar --set $NAME \
        background.color=$BLUE \
        icon.color=$BLACK
else
    # Normal workspace
    sketchybar --set $NAME \
        background.color=$TRANSPARENT \
        icon.color=$WHITE
fi
