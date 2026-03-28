local M = {}

local managed_toggle_terms = {}

local function compact_managed_terms()
  local kept = {}
  for _, term in ipairs(managed_toggle_terms) do
    if term and term.toggle and (not term.bufnr or vim.api.nvim_buf_is_valid(term.bufnr)) then table.insert(kept, term) end
  end
  managed_toggle_terms = kept
  return managed_toggle_terms
end

local function schedule_compact_managed_terms() vim.schedule(compact_managed_terms) end

function M.setup()
  local copilot = require 'config.copilot'

  vim.keymap.set('n', '<leader>tt', function()
    local ok = pcall(require, 'toggleterm.terminal')
    if not ok then
      vim.notify('ToggleTerm not found. Run :Lazy to check installation.', vim.log.levels.WARN)
      return
    end

    copilot.hide_terminal_if_visible()

    local terms = compact_managed_terms()
    if #terms == 0 then return end

    local has_visible = false
    for _, term in ipairs(terms) do
      if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) and vim.fn.bufwinid(term.bufnr) ~= -1 then
        has_visible = true
        break
      end
    end

    if has_visible then
      for _, term in ipairs(terms) do
        if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
          local win = vim.fn.bufwinid(term.bufnr)
          if win ~= -1 then vim.api.nvim_win_close(win, true) end
        end
      end
      schedule_compact_managed_terms()
      return
    end

    for _, term in ipairs(terms) do
      term:toggle()
    end
  end, { desc = 'Toggle existing terminals' })

  vim.keymap.set('n', '<leader>tn', function()
    local ok, terminal_mod = pcall(require, 'toggleterm.terminal')
    if not ok then
      vim.notify('ToggleTerm not found. Run :Lazy to check installation.', vim.log.levels.WARN)
      return
    end

    copilot.hide_terminal_if_visible()

    local Terminal = terminal_mod.Terminal
    local new_term = Terminal:new {
      direction = 'horizontal',
      hidden = true,
      on_open = function() vim.cmd 'startinsert!' end,
      on_close = schedule_compact_managed_terms,
      on_exit = schedule_compact_managed_terms,
    }
    table.insert(managed_toggle_terms, new_term)
    new_term:toggle()
  end, { desc = 'Open new horizontal terminal' })

  vim.keymap.set('n', '<leader>tk', function()
    local buf = vim.api.nvim_get_current_buf()
    local is_terminal = vim.bo[buf].buftype == 'terminal' or vim.bo[buf].filetype == 'toggleterm'
    if not is_terminal then
      vim.notify('Current buffer is not a terminal', vim.log.levels.WARN)
      return
    end
    vim.api.nvim_buf_delete(buf, { force = true })
    schedule_compact_managed_terms()
  end, { desc = 'Kill current terminal buffer' })
end

return M
