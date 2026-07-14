-- Keep startup-critical globals here and load the rest from lua/config/*.lua.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Optional providers that this config does not use.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- Pin provider executables early so Neovim does not need to discover them later.
local pynvim_host_prog = vim.fn.expand '~/.local/share/nvim/pynvim-venv/bin/python'
if vim.fn.executable(pynvim_host_prog) == 1 then
  vim.g.python3_host_prog = pynvim_host_prog
else
  local python3_host_prog = vim.fn.exepath 'python3'
  if python3_host_prog ~= '' then vim.g.python3_host_prog = python3_host_prog end
end

local node_host_prog = vim.fn.exepath 'neovim-node-host'
if node_host_prog ~= '' then vim.g.node_host_prog = node_host_prog end

require('config.options').setup()
require('config.keymaps').setup()
require('config.opencode').setup()
require('config.terminals').setup()
require('config.autocmds').setup()
require('config.lazy').setup()

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
