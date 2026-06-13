---
applyTo: "**"
---

# User Memory

## User Preferences

- Programming languages: Lua (Neovim config context inferred)
- Code style preferences: Keep existing project style
- Development environment: Neovim on macOS
- Communication style: Concise and practical

## Project Context

- Current project type: Neovim configuration
- Tech stack: Lua, Neovim plugins
- Architecture patterns: Modular plugin/keymap configuration
- Key requirements: Improve search picker UX by preserving previous query
- Repo structure: `init.lua` is a thin entrypoint; `lua/config/*.lua` contains runtime wiring; `lua/plugins/*.lua` contains lazy.nvim plugin specs auto-imported by `lua/config/lazy.lua`
- Repo-specific subsystem: custom OpenCode integration lives under `lua/config/opencode/`
- Verification/tooling: CI only checks `stylua --check .`; no repo-local test/lint/typecheck script was found

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
- User later asked why `<leader>cp` opens cosmic-term even with alacritty as default terminal.
- Root cause found in `lua/config/opencode/external.lua`: the launcher preference order hard-codes `cosmic-term` first, and `build_external_terminal_command()` picks the first executable launcher unless `vim.g.opencode_external_terminal` overrides it.
- Updated plan for `<leader>cp`: prefer `$TERMINAL` when set, then detect the current terminal via terminal-specific env vars (`ALACRITTY_WINDOW_ID`, `KITTY_WINDOW_ID`/`KITTY_PID`, `WEZTERM_PANE`, `GHOSTTY_RESOURCES_DIR`/`GHOSTTY_BIN_DIR`, `FOOT_SESSION`, `GNOME_TERMINAL_SCREEN`, `KONSOLE_VERSION`), then fall back to the existing executable preference list.
- Fixed a regression in the detection path where the launcher was being resolved before `cwd` was available; detection now returns the terminal name and rebuilds the launcher with the real working directory.
- User requested a compact `AGENTS.md` for this repository.
- Verified there was no existing `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`, or `opencode.json` in the repo.
- Verified high-value sources for agent instructions: `README.md`, `init.lua`, `.stylua.toml`, `.github/workflows/stylua.yml`, `lazy-lock.json`, `lua/config/lazy.lua`, and representative modules under `lua/config/` and `lua/plugins/`.
- High-signal guidance extracted for `AGENTS.md`: module boundaries, StyLua-only CI, plugin build prerequisites (`make`, `cargo`, `deno`), and custom OpenCode/Telescope behavior that an agent could accidentally break.

## Structure

- `init.lua` is intentionally small: it sets startup-critical globals, then loads modules in this order: `config.options` -> `config.keymaps` -> `config.opencode` -> `config.terminals` -> `config.autocmds` -> `config.lazy`.
- `lua/config/*.lua` is the hand-written runtime wiring. `lua/plugins/*.lua` is only lazy.nvim plugin specs; they are auto-imported by `lua/config/lazy.lua` via `{ import = 'plugins' }`.
- The custom OpenCode integration is all under `lua/config/opencode/` (`init.lua`, `terminal.lua`, `external.lua`, `commit.lua`, `util.lua`). If a change affects `<leader>cP`, `<leader>cp`, or `<leader>cm`, start there.

## Verification and developer commands

- Formatting is enforced with StyLua only. CI runs `stylua --check .`, and the repo style is defined in `.stylua.toml` (2 spaces, 160 columns, `AutoPreferSingle`, `call_parentheses = "None"`).
- There is no repo-local test runner, lint script, or typecheck script beyond Neovim/plugin tooling; do not invent `npm`, `make test`, or similar workflows here.
- `:ConformInfo` is the built-in way to inspect formatter resolution.
- If Markdown preview is broken, `peek.nvim` expects Deno and its own code explicitly tells users to run `:Lazy build peek.nvim` after installing Deno.

## Toolchain quirks

- `telescope-fzf-native.nvim` only builds when `make` is executable.
- `blink.cmp` only runs its native `cargo build --release` step when `cargo` exists.
- `peek.nvim` builds preview assets with `deno task build:fast` inside the plugin directory.
- Mason tool installation is driven from `lua/plugins/lsp.lua`; keep `ensure_installed` in sync with formatter/LSP changes instead of adding ad hoc setup elsewhere.

## Repo-specific behavior worth preserving

- Telescope `<leader>s*` pickers intentionally preserve the previous prompt text through `with_persistent_prompt()` in `lua/plugins/telescope.lua`; avoid removing that stateful wrapper by accident.
- The internal OpenCode terminal and generic ToggleTerm terminals are managed separately. `lua/config/terminals.lua` hides the OpenCode terminal before opening managed terminals and tracks only the terminals it created.
- Internal OpenCode uses `opencode --model github-copilot/gpt-4.1` in a right-side terminal split.
- External OpenCode also uses `github-copilot/gpt-4.1`, requires both `opencode` and `tmux`, opens Terminal.app through `osascript` on macOS, and on non-macOS uses either `vim.g.opencode_external_terminal`, the current terminal environment, or a built-in fallback list.
- `<leader>cm` generates commit messages from `git diff --staged` via `opencode run ... --model github-copilot/gpt-4.1` and copies the result to both the unnamed and system clipboard registers.

## Notes

- Do not store sensitive information.
- Goal is UX improvement with minimal changes and no extra dependencies.
- `luac` not available in environment; used headless Neovim parse/load check instead.
