-- Keep startup-critical globals here and load the rest from lua/config/*.lua.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

require('config.options').setup()
require('config.keymaps').setup()
require('config.copilot').setup()
require('config.terminals').setup()
require('config.autocmds').setup()
require('config.lazy').setup()

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
