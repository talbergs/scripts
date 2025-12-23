# Fish Config v42

Minimal, transient fish shell configuration with informative prompts.

## Features

**Transient Prompt** - Previous commands show minimal `⊱⋅` prompt, current line shows full context.

**Left Prompt**
- Background jobs list with status (`◆` running, `◇` stopped)
- Exit code on failure (`× code`)
- Full PWD with `~` home substitution
- Git branch + state (REBASING, MERGING, CHERRY-PICKING, BISECTING)

**Right Prompt** (two lines)
- Shell depth chain: `zsh › fish (lvl 2)`
- Command duration with timestamps: `2025-12-22 [14:30:00 → 14:30:24](~24s)`

## Keybindings

| Key | Action |
|-----|--------|
| `Ctrl-Z` | Bring background job to foreground |
| `Ctrl-F` | Fuzzy file picker (fd + fzf) |

## Functions

- `pwd:get` - cd to last used directory (persisted across sessions)
- `l` - ls with details, sorted by time
- `h` - merge shell history

## Abbreviations

`g` git, `gst` status, `ga` add, `gc` commit, `gp` push, `gb` branch, `gd` diff, `gr` remote, `gco` checkout, `glog` log, `+x` chmod +x, `rmf` rm -rf

## Icons

```
⋕  root prompt
⊱⋅ user prompt
◆  running job
◇  stopped job
×  failed command
›  shell chain
```

## Requirements

- fish shell
- fd (file finder)
- fzf (fuzzy finder)
- git
