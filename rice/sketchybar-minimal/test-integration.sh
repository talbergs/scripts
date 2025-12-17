#!/usr/bin/env bash

# Quick test to verify aerospace + sketchybar integration

echo "Testing Aerospace + SketchyBar Integration"
echo "==========================================="
echo

# Get current workspace
CURRENT=$(aerospace list-workspaces --focused 2>/dev/null)
echo "Current workspace: $CURRENT"
echo

# Manually trigger the event
echo "Triggering workspace change event for workspace $CURRENT..."
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$CURRENT

echo
echo "✅ Event triggered!"
echo "Check your SketchyBar - workspace $CURRENT should be highlighted"
echo
echo "Now try switching workspaces with Alt+1, Alt+2, etc."
echo "The highlighting should update automatically."
