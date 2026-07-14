local M = {}

local commit = require 'config.opencode.commit'
local external = require 'config.opencode.external'
local terminal = require 'config.opencode.terminal'
local util = require 'config.opencode.util'

function M.hide_terminal_if_visible() terminal.hide_terminal_if_visible() end

function M.setup()
  vim.keymap.set('n', '<leader>cP', function() terminal.toggle() end, { desc = 'Pi CLI toggle' })

  vim.keymap.set('x', '<leader>cP', function()
    local reference = util.get_visual_reference()
    if not reference then return end

    if terminal.send_reference(reference) then util.leave_visual_mode() end
  end, { desc = 'Pi CLI with range ref' })

  vim.keymap.set('n', '<leader>cp', function() external.open() end, { desc = 'Pi CLI in external terminal' })

  vim.keymap.set('x', '<leader>cp', function()
    local reference = util.get_visual_reference()
    if not reference then return end

    util.leave_visual_mode()
    vim.schedule(function()
      external.open {
        initial_prompt = reference,
        open_existing = false,
      }
    end)
  end, { desc = 'Pi CLI in external terminal with range ref' })

  vim.keymap.set('n', '<leader>cm', function() commit.generate() end, { desc = 'Pi [C]ommit [M]essage to clipboard' })
end

return M
