#!/usr/bin/env bash

# Check if aerospace integration is properly configured

echo "Checking Aerospace + SketchyBar Integration..."
echo "=============================================="
echo

# Check if aerospace is installed
if ! command -v aerospace &> /dev/null; then
    echo "❌ Aerospace is not installed or not in PATH"
    exit 1
else
    echo "✅ Aerospace is installed"
fi

# Check if sketchybar is installed
if ! command -v sketchybar &> /dev/null; then
    echo "❌ SketchyBar is not installed or not in PATH"
    exit 1
else
    echo "✅ SketchyBar is installed"
fi

# Check if aerospace config exists
if [ ! -f ~/.aerospace.toml ]; then
    echo "❌ Aerospace config file (~/.aerospace.toml) not found"
    exit 1
else
    echo "✅ Aerospace config file exists"
fi

# Check if exec-on-workspace-change is configured
if grep -q "exec-on-workspace-change" ~/.aerospace.toml; then
    echo "✅ exec-on-workspace-change is configured"
    
    # Check if it triggers sketchybar
    if grep -q "sketchybar --trigger aerospace_workspace_change" ~/.aerospace.toml; then
        echo "✅ Configured to trigger SketchyBar event"
    else
        echo "⚠️  exec-on-workspace-change exists but doesn't trigger SketchyBar"
        echo "   Add this to ~/.aerospace.toml:"
        echo "   exec-on-workspace-change = ['/bin/bash', '-c', 'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=\$AEROSPACE_FOCUSED_WORKSPACE']"
    fi
else
    echo "❌ exec-on-workspace-change NOT configured"
    echo
    echo "Add this to your ~/.aerospace.toml file:"
    echo "----------------------------------------"
    echo "exec-on-workspace-change = ["
    echo "    '/bin/bash', '-c',"
    echo "    'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=\$AEROSPACE_FOCUSED_WORKSPACE'"
    echo "]"
    echo
    exit 1
fi

echo
echo "Testing workspace detection..."
CURRENT_WORKSPACE=$(aerospace list-workspaces --focused 2>/dev/null)
if [ -n "$CURRENT_WORKSPACE" ]; then
    echo "✅ Current workspace: $CURRENT_WORKSPACE"
else
    echo "⚠️  Could not detect current workspace"
fi

echo
echo "All checks passed! 🎉"
echo
echo "To apply changes:"
echo "  1. aerospace reload-config"
echo "  2. brew services restart sketchybar"
