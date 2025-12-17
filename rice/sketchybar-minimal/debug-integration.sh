#!/usr/bin/env bash

# Debug aerospace + sketchybar integration

echo "🔍 Debugging Aerospace + SketchyBar Integration"
echo "================================================"
echo

# 1. Check if aerospace is running
echo "1. Checking if aerospace is running..."
if pgrep -x "AeroSpace" > /dev/null; then
    echo "   ✅ Aerospace is running (PID: $(pgrep -x "AeroSpace"))"
else
    echo "   ❌ Aerospace is NOT running"
    echo "   Start it with: open -a AeroSpace"
fi
echo

# 2. Check if sketchybar is running
echo "2. Checking if sketchybar is running..."
if pgrep -x "sketchybar" > /dev/null; then
    echo "   ✅ SketchyBar is running (PID: $(pgrep -x "sketchybar"))"
else
    echo "   ❌ SketchyBar is NOT running"
    echo "   Start it with: brew services start sketchybar"
fi
echo

# 3. Check aerospace config
echo "3. Checking aerospace config for exec-on-workspace-change..."
if [ -f ~/.aerospace.toml ]; then
    if grep -q "exec-on-workspace-change" ~/.aerospace.toml; then
        echo "   ✅ Found exec-on-workspace-change in config"
        echo "   Config line:"
        grep -A 1 "exec-on-workspace-change" ~/.aerospace.toml | head -2
    else
        echo "   ❌ exec-on-workspace-change NOT found in ~/.aerospace.toml"
        echo "   You need to add it!"
    fi
else
    echo "   ❌ ~/.aerospace.toml not found"
fi
echo

# 4. Test aerospace command
echo "4. Testing aerospace workspace detection..."
CURRENT_WS=$(aerospace list-workspaces --focused 2>&1)
if [ $? -eq 0 ]; then
    echo "   ✅ Current workspace: $CURRENT_WS"
else
    echo "   ❌ Error getting workspace: $CURRENT_WS"
fi
echo

# 5. Check sketchybar events
echo "5. Checking sketchybar registered events..."
sketchybar --query bar 2>&1 | grep -i "aerospace" || echo "   ⚠️  No aerospace events found"
echo

# 6. Test manual trigger
echo "6. Testing manual event trigger..."
echo "   Running: sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$CURRENT_WS"
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$CURRENT_WS 2>&1
if [ $? -eq 0 ]; then
    echo "   ✅ Trigger command executed"
else
    echo "   ❌ Trigger command failed"
fi
echo

# 7. Check plugin script
echo "7. Checking aerospace plugin script..."
PLUGIN="$SCRIPTS_DIR/rice/sketchybar-minimal/plugins/aerospace.sh"
if [ -f "$PLUGIN" ]; then
    echo "   ✅ Plugin exists: $PLUGIN"
    if [ -x "$PLUGIN" ]; then
        echo "   ✅ Plugin is executable"
    else
        echo "   ❌ Plugin is NOT executable"
        echo "   Fix with: chmod +x $PLUGIN"
    fi
else
    echo "   ❌ Plugin not found: $PLUGIN"
fi
echo

# 8. Test plugin directly
echo "8. Testing plugin script directly..."
echo "   Running plugin for workspace $CURRENT_WS..."
export NAME="space.$CURRENT_WS"
export FOCUSED_WORKSPACE="$CURRENT_WS"
bash -x "$PLUGIN" "$CURRENT_WS" 2>&1 | head -20
echo

# 9. Check logs
echo "9. Checking for aerospace/sketchybar logs..."
echo "   Aerospace logs (if any):"
if [ -d ~/Library/Logs/AeroSpace ]; then
    ls -lh ~/Library/Logs/AeroSpace/ 2>/dev/null || echo "   No logs found"
else
    echo "   No log directory found"
fi
echo

echo "   SketchyBar logs:"
if [ -f /tmp/sketchybar.log ]; then
    echo "   Last 10 lines of /tmp/sketchybar.log:"
    tail -10 /tmp/sketchybar.log
else
    echo "   No /tmp/sketchybar.log found"
fi
echo

echo "================================================"
echo "🎯 Next Steps:"
echo "1. If aerospace config is missing exec-on-workspace-change, run: scripts:conf"
echo "2. If aerospace is not running, start it"
echo "3. If sketchybar is not running, start it"
echo "4. Try switching workspaces and watch for changes"
