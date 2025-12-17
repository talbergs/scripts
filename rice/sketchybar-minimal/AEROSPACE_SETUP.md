# Aerospace Configuration for SketchyBar Integration

To make the workspace highlighting work correctly, you need to configure **aerospace** to trigger a SketchyBar event whenever you change workspaces.

## Required Configuration

Add this to your `~/.aerospace.toml` file:

```toml
# Trigger SketchyBar event on workspace change
exec-on-workspace-change = [
    '/bin/bash', '-c',
    'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE'
]
```

## Where to Add It

Add this configuration in the main section of your `~/.aerospace.toml` file, typically near the top after any `start-at-login` or `enable-normalization-*` settings.

### Example Full Configuration Section

```toml
# Start AeroSpace at login
start-at-login = true

# Normalizations
enable-normalization-flatten-containers = true
enable-normalization-opposite-orientation-for-nested-containers = true

# SketchyBar integration
exec-on-workspace-change = [
    '/bin/bash', '-c',
    'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE'
]
```

## How It Works

1. When you change workspaces in aerospace (via keyboard shortcuts or clicking in SketchyBar)
2. Aerospace executes the `exec-on-workspace-change` command
3. This triggers the `aerospace_workspace_change` event in SketchyBar
4. The event passes the `FOCUSED_WORKSPACE` environment variable
5. All workspace items subscribed to this event run their scripts
6. The scripts check if their workspace matches the focused one and update highlighting accordingly

## Testing

After adding this configuration:

1. Restart aerospace: `aerospace reload-config` or restart the app
2. Restart SketchyBar: `brew services restart sketchybar`
3. Switch between workspaces - the highlighting should now update correctly

## Troubleshooting

If the highlighting still doesn't work:

1. Check if aerospace is running: `ps aux | grep -i aerospace`
2. Verify the event is being triggered: `sketchybar --query bar` should show the event
3. Check SketchyBar logs for errors
4. Ensure the plugin script is executable: `ls -la ~/scripts/rice/sketchybar-minimal/plugins/aerospace.sh`

## Alternative: Manual Testing

You can manually trigger the event to test:

```bash
sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=2
```

This should highlight workspace 2 in your bar.
