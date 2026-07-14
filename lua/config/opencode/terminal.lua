local M = {}
local pi = require 'config.opencode.pi'

local opencode_term_buf = nil
local opencode_term = nil

local function hide_other_terminal_windows(except_buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if buf ~= except_buf then
      local is_terminal = vim.bo[buf].filetype == 'toggleterm' or vim.bo[buf].buftype == 'terminal'
      if is_terminal then vim.api.nvim_win_close(win, true) end
    end
  end
end

local function place_opencode_terminal_right()
  if not opencode_term_buf or not vim.api.nvim_buf_is_valid(opencode_term_buf) then return end

  local win = vim.fn.bufwinid(opencode_term_buf)
  if win == -1 then return end

  vim.api.nvim_set_current_win(win)
  vim.cmd 'wincmd L'
  vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * 0.4))
end

function M.hide_terminal_if_visible()
  if not opencode_term_buf or not vim.api.nvim_buf_is_valid(opencode_term_buf) then return end

  local win = vim.fn.bufwinid(opencode_term_buf)
  if win ~= -1 then vim.api.nvim_win_close(win, true) end
end

local function focus_terminal_if_visible()
  if not opencode_term_buf or not vim.api.nvim_buf_is_valid(opencode_term_buf) then return end

  local win = vim.fn.bufwinid(opencode_term_buf)
  if win ~= -1 then
    hide_other_terminal_windows(opencode_term_buf)
    place_opencode_terminal_right()
  end
end

local function ensure_opencode_term()
  if vim.fn.executable(pi.executable) ~= 1 then
    vim.notify('Pi CLI not found in $PATH', vim.log.levels.ERROR)
    return false
  end

  local ok, terminal_mod = pcall(require, 'toggleterm.terminal')
  if ok and terminal_mod and terminal_mod.Terminal then
    local Terminal = terminal_mod.Terminal
    if opencode_term and opencode_term.bufnr and vim.api.nvim_buf_is_valid(opencode_term.bufnr) then
      local win = vim.fn.bufwinid(opencode_term.bufnr)
      if win == -1 then opencode_term:toggle() end
      opencode_term_buf = opencode_term.bufnr
      return true
    end

    opencode_term = Terminal:new {
      cmd = table.concat(pi.args(), ' '),
      direction = 'vertical',
      hidden = true,
      close_on_exit = false,
      on_open = function(term) opencode_term_buf = term.bufnr end,
    }

    opencode_term:toggle()
    if opencode_term.bufnr and vim.api.nvim_buf_is_valid(opencode_term.bufnr) then
      opencode_term_buf = opencode_term.bufnr
      return true
    end

    vim.defer_fn(function()
      if opencode_term and opencode_term.bufnr and vim.api.nvim_buf_is_valid(opencode_term.bufnr) then opencode_term_buf = opencode_term.bufnr end
    end, 50)

    return true
  end

  vim.cmd 'botright vsplit'
  vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * 0.4))
  vim.cmd('terminal ' .. table.concat(pi.args(), ' '))
  opencode_term_buf = vim.api.nvim_get_current_buf()
  return true
end

function M.toggle()
  if opencode_term and opencode_term.toggle then
    local was_visible = opencode_term.bufnr and vim.api.nvim_buf_is_valid(opencode_term.bufnr) and vim.fn.bufwinid(opencode_term.bufnr) ~= -1
    opencode_term:toggle()
    if not was_visible and opencode_term.bufnr and vim.api.nvim_buf_is_valid(opencode_term.bufnr) then focus_terminal_if_visible() end
    return
  end

  if opencode_term_buf and vim.api.nvim_buf_is_valid(opencode_term_buf) then
    local win = vim.fn.bufwinid(opencode_term_buf)
    if win ~= -1 then
      vim.api.nvim_win_close(win, true)
      return
    end
  end

  if not ensure_opencode_term() then return end
  focus_terminal_if_visible()
end

function M.send_reference(reference)
  if not ensure_opencode_term() then return false end

  focus_terminal_if_visible()

  local buf = opencode_term_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    vim.notify('Pi terminal buffer is not available', vim.log.levels.ERROR)
    return false
  end

  local ok, job_id = pcall(vim.api.nvim_buf_get_var, buf, 'terminal_job_id')
  if not ok or type(job_id) ~= 'number' then
    vim.notify('Pi terminal is not ready', vim.log.levels.ERROR)
    return false
  end

  vim.fn.chansend(job_id, reference .. '\n')
  return true
end

return M
