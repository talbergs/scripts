# Debugging Aerospace + SketchyBar Integration

## Quick Debug Commands

### 1. Run the debug script
```bash
~/scripts/rice/sketchybar-minimal/debug-integration.sh
```

### 2. Watch the logs in real-time
```bash
# In one terminal, tail the log
tail -f /tmp/sketchybar-aerospace.log

# In another terminal, switch workspaces (Alt+1, Alt+2, etc.)
```

### 3. Check if aerospace config was applied
```bash
grep "exec-on-workspace-change" ~/.aerospace.toml
```

### 4. Manually test the event trigger
```bash
# Get current workspace
aerospace list-workspaces --focused

# Trigger the event manually (replace "2" with your current workspace)
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=2

# Check the log
cat /tmp/sketchybar-aerospace.log
```

### 5. Check if processes are running
```bash
pgrep -fl "AeroSpace|sketchybar"
```

## Common Issues

### Issue: Workspace 1 always highlighted

**Cause**: Aerospace is not triggering the event when you switch workspaces.

**Check**:
1. Is `exec-on-workspace-change` in `~/.aerospace.toml`?
   ```bash
   grep -A 1 "exec-on-workspace-change" ~/.aerospace.toml
   ```

2. Did you reload aerospace config?
   ```bash
   aerospace reload-config
   ```

### Issue: No logs appearing

**Cause**: The plugin script is not being called.

**Check**:
1. Is SketchyBar using the right config?
   ```bash
   sketchybar --query bar | grep -i config
   ```

2. Are the workspace items registered?
   ```bash
   sketchybar --query space.1
   sketchybar --query space.2
   ```

### Issue: FOCUSED_WORKSPACE is empty in logs

**Cause**: Aerospace is not passing the variable, or the event is not being triggered.

**Fix**:
1. Verify aerospace config has the exact line:
   ```toml
   exec-on-workspace-change = ['/bin/bash', '-c', 'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']
   ```

2. Reload aerospace:
   ```bash
   aerospace reload-config
   ```

## Log Files

- **Aerospace plugin log**: `/tmp/sketchybar-aerospace.log`
- **Debug plugin log**: `/tmp/sketchybar-aerospace-debug.log`
- **SketchyBar log** (if exists): `/tmp/sketchybar.log`
- **Aerospace logs**: `~/Library/Logs/AeroSpace/`

## Testing Workflow

1. **Clear the log**:
   ```bash
   rm /tmp/sketchybar-aerospace.log
   ```

2. **Restart SketchyBar**:
   ```bash
   brew services restart sketchybar
   # or killall sketchybar && sketchybar &
   ```

3. **Watch the log**:
   ```bash
   tail -f /tmp/sketchybar-aerospace.log
   ```

4. **Switch workspaces** (Alt+1, Alt+2, etc.) and watch the log output

5. **Expected log output**:
   ```
   === Thu Dec 12 11:00:00 EET 2024 === workspace_id=1 NAME=space.1 FOCUSED_WORKSPACE=2
     -> Unhighlighting 1
   === Thu Dec 12 11:00:00 EET 2024 === workspace_id=2 NAME=space.2 FOCUSED_WORKSPACE=2
     -> Highlighting 2
   ```

## If Still Not Working

Run this complete diagnostic:
```bash
echo "=== Aerospace Config ==="
grep -A 1 "exec-on-workspace-change" ~/.aerospace.toml

echo -e "\n=== Current Workspace ==="
aerospace list-workspaces --focused

echo -e "\n=== Manual Trigger Test ==="
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=1

echo -e "\n=== Check Log ==="
cat /tmp/sketchybar-aerospace.log

echo -e "\n=== SketchyBar Items ==="
sketchybar --query space.1 2>&1 | head -5
```
