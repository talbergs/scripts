# SketchyBar Minimal Configuration

A minimal SketchyBar configuration featuring:
- **Aerospace Workspaces**: Shows all workspaces with visual highlighting of the active one
- **Clock**: Displays current time and date
- **Battery**: Shows battery percentage with color-coded status

## Structure

```
sketchybar-minimal/
├── sketchybarrc          # Main configuration file
├── sketchybarrc.lua      # Lua-based version (experimental)
└── plugins/
    ├── aerospace.sh      # Aerospace workspace indicator
    ├── clock.sh          # Clock display
    └── battery.sh        # Battery status
```

## Installation

1. **Link or copy to SketchyBar config directory:**
   ```bash
   ln -sf ~/scripts/rice/sketchybar-minimal ~/.config/sketchybar
   ```

2. **Configure Aerospace** (REQUIRED for workspace highlighting):
   
   Add this to your `~/.aerospace.toml` file:
   ```toml
   exec-on-workspace-change = [
       '/bin/bash', '-c',
       'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE'
   ]
   ```
   
   See [AEROSPACE_SETUP.md](file:///Users/mtalbergs/scripts/rice/sketchybar-minimal/AEROSPACE_SETUP.md) for detailed instructions.

3. **Restart both services:**
   ```bash
   aerospace reload-config
   brew services restart sketchybar
   ```

## Features

### Aerospace Workspaces
- Displays all available workspaces on the left side
- Highlights the currently focused workspace with blue background
- Click on any workspace to switch to it
- Fallback to workspaces 1-5 if aerospace is not available

### Clock
- Shows time in 24-hour format (HH:MM)
- Displays abbreviated day and date (e.g., "Mon 11 Dec")
- Updates every second
- Blue background with black text

### Battery
- Shows battery percentage
- Displays charging icon (󰂄) when plugged in
- Displays battery icon (󰁹) when on battery
- Color-coded background:
  - **Green**: 50%+ charge
  - **Yellow**: 20-49% charge
  - **Red**: Below 20% charge
- Updates every 30 seconds

## Customization

### Colors
Edit the color variables at the top of `sketchybarrc`:
- `BAR_COLOR`: Background color of the bar
- `BLUE`, `GREEN`, `YELLOW`, `RED`: Item colors
- `WHITE`, `BLACK`: Text colors

### Bar Position
Change `position=top` to `position=bottom` in the bar setup section.

### Update Frequency
Modify `update_freq` values in the item definitions:
- Clock: Currently 1 second
- Battery: Currently 30 seconds

## Requirements

- [SketchyBar](https://github.com/FelixKratz/SketchyBar)
- [Aerospace](https://github.com/nikitabobko/AeroSpace) (optional, will fallback to numbered workspaces)
- SF Pro font (included with macOS)

## Notes

- The Lua version (`sketchybarrc.lua`) is experimental and may require SketchyBar's Lua plugin
- The shell version (`sketchybarrc`) is the recommended configuration
- Plugin scripts must be executable (already set via chmod +x)
