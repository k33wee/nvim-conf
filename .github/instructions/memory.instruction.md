---
applyTo: '**'
---

# User Memory

## User Preferences
- Programming languages: Lua (Neovim config context inferred)
- Code style preferences: Keep existing project style
- Development environment: Neovim on Linux
- Communication style: Concise and practical

## Project Context
- Current project type: Neovim configuration
- Tech stack: Lua, Neovim plugins
- Architecture patterns: Modular plugin/keymap configuration
- Key requirements: Improve search picker UX by preserving previous query

## Coding Patterns
- Prefer minimal, focused changes in existing config files
- Keep behavior consistent with existing keybinding conventions

## Context7 Research History
- Attempted Context7 search endpoint for telescope query persistence (`https://context7.com/search?q=telescope.nvim+default_text`), but content is JS-rendered and not directly retrievable via static fetch.
- Fetched official Telescope documentation and source directly from GitHub/raw endpoints.
- Confirmed picker internals support `default_text` and `on_input_filter_cb` with callback return shape `{ prompt = <string>, updated_finder = <finder>|nil }`.

## Conversation History
- User requested: when reopening `<leader>,s,<any-key>` search, prefill with previous search text instead of empty input.
- Located relevant mappings in `lua/plugins/telescope.lua` under `<leader>s*`.
- Planned implementation: add lightweight prompt-state wrapper that stores last prompt text and injects it via `default_text`.
- Implemented persistent prompt wrappers in `lua/plugins/telescope.lua`:
  - Added `last_search_text` state
  - Added `with_persistent_prompt(opts)` to set `default_text` and capture prompt changes through `on_input_filter_cb`
  - Routed `<leader>s*` search-related mappings through `open_search(...)` so reopened pickers prefill previous query
  - Kept `<leader>sw` and `<leader>sr` behavior unchanged intentionally
- Validation:
  - `nvim --headless "+lua dofile('lua/plugins/telescope.lua')" +qa` succeeded (no output)

## Notes
- Do not store sensitive information.
- Goal is UX improvement with minimal changes and no extra dependencies.
- `luac` not available in environment; used headless Neovim parse/load check instead.
