# Neovim Config Features (v0.12.0)

## 1. Plugin Management
- Custom `vim.pack.add` with callback system (`vim.user.set_cb_packs`)
- Lazy callback execution after plugin load

## 2. LSP Configuration
- **lua_ls**: Lua language server with LuaJIT runtime, vim globals
- **intelephense**: PHP language server with license key
- **Mason**: Auto-install LSP servers (lua_ls, stylua, intelephense, phpcs, phpcbf, pyright, html-lsp, css-lsp, typescript-language-server, rust_analyzer)
- Dynamic LSP enable from mason schemas

## 3. AI/LLM Integrations
- **Ollama Ghost**: Local ghost-text completions via `agent.sh`
  - Model: deepseek-coder:6.7b
  - Keymaps: `<C-g>` accept/trigger, `<C-]>` cancel, `<leader>og` complete, `<leader>oc` cancel
- **TODO Agent**: Periodic buffer scanning for TODOs
  - 5-second scan interval, 15 lines context
  - Icons: pending (○), loading (◐), ready (●), error (✗)
  - Keymaps: `K` hover, `<leader>Ts` scan, `<leader>Tr` refresh, `<leader>Tc` clear, `<leader>Tt` toggle
- **Claude Code**: claudecode.nvim integration
- **gen.nvim, llm.nvim, nvim-gemini-companion**: Additional LLM plugins

## 4. Completion (nvim-cmp)
- Sources: nvim_lsp, luasnip, buffer, path, calc
- Keymaps: `<C-b>`/`<C-f>` scroll docs, `<C-Space>` complete, `<C-e>` abort, `<CR>` confirm, `<Tab>`/`<S-Tab>` navigate

## 5. Treesitter
- Languages: go, lua, python, rust, typescript, yaml, json, nix, bash, php, html, css, javascript, c, cpp, markdown
- Context plugin (disabled by default, toggle with `<F3>`)

## 6. Git Integration
- **gitsigns.nvim**: Hunk preview (`<leader>hp`), reset (`<leader>hr`), navigation (`[c`/`]c`)
- **vim-fugitive**: Git wrapper

## 7. File Management
- **Oil.nvim**: File explorer (`<leader>n`)
- **Telescope**: Buffers (`<leader>b`), files (`<leader>f`), grep (`<leader>g`/`<leader>F`), fuzzy find (`<leader>l`), symbols (`t`/`<leader>t`)

## 8. Debugging (DAP)
- Toggle UI: `<leader>du`
- Breakpoints: `<leader>db` toggle, `<leader>dB` conditional
- Stepping: `<leader>dc` continue, `<leader>dd` step over, `<leader>di` step into, `<leader>do` step out
- Widgets: `<leader>dws` scopes, `<leader>dwf` frames, `<leader>dh` hover, `<leader>dH` preview

## 9. LSP Features
- References: `gr`
- Implementation: `gi`
- Type definition: `gt`
- Code action: `<leader>a`
- Rename: `<leader>r`
- Sticky highlights: `gh` add, `gH` clear
- Document highlight on CursorHold (1.5s delay)

## 10. Global Options
- Line numbers, tabs (4 spaces), smart indent
- No swap/backup, persistent undo (`/tmp/nixvim/undodir`)
- Fold method: indent (disabled)
- Update time: 50ms
- Winbar: filename

## 11. Filetype Settings
- **YAML**: 2-space indent, `#` comments
- **Nix**: 2-space indent, `#` comments
- **Zabbix repos**: 4-space tabs (no expand)

## 12. Navigation & Editing
- Fast scroll: `<C-j>`/`<C-k>` (10 lines), `<C-h>`/`<C-l>` (horizontal)
- Scroll: `<C-y>`/`<C-e>` (2 lines)
- Quickfix: `<A-=>`/`<A-->` next/prev
- Tabs: `<A-j>`/`<A-k>` prev/next, `<A-<>`/`<A->` move
- Window resize: `<C-arrows>`
- Macro replay: `<CR>`
- Clear search: `Q`

## 13. Toggles
- Spell: `<F1>`
- List chars: `<F2>`
- Treesitter context: `<F3>`

## 14. Other Plugins
- **which-key.nvim**: Key hints (3s delay)
- **quicker.nvim**: Quickfix enhancements
- **undotree**: Undo visualization
- **nvim-colorizer.lua**: Color highlighting
- **lualine.nvim**: Statusline
- **conform.nvim**: Formatting
- **vim-commentary**: Commenting
- **macaltkey.nvim**: Mac alt-key support
