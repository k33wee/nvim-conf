local M = {}

local copilot_term_buf = nil
local copilot_term = nil

local function hide_other_terminal_windows(except_buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if buf ~= except_buf then
      local is_terminal = vim.bo[buf].filetype == 'toggleterm' or vim.bo[buf].buftype == 'terminal'
      if is_terminal then vim.api.nvim_win_close(win, true) end
    end
  end
end

local function place_copilot_terminal_right()
  if not copilot_term_buf or not vim.api.nvim_buf_is_valid(copilot_term_buf) then return end

  local win = vim.fn.bufwinid(copilot_term_buf)
  if win == -1 then return end

  vim.api.nvim_set_current_win(win)
  vim.cmd 'wincmd L'
  vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * 0.4))
end

function M.hide_terminal_if_visible()
  if not copilot_term_buf or not vim.api.nvim_buf_is_valid(copilot_term_buf) then return end

  local win = vim.fn.bufwinid(copilot_term_buf)
  if win ~= -1 then vim.api.nvim_win_close(win, true) end
end

local function focus_terminal_if_visible()
  if not copilot_term_buf or not vim.api.nvim_buf_is_valid(copilot_term_buf) then return end

  local win = vim.fn.bufwinid(copilot_term_buf)
  if win ~= -1 then
    hide_other_terminal_windows(copilot_term_buf)
    place_copilot_terminal_right()
  end
end

local function ensure_copilot_term()
  local ok, terminal_mod = pcall(require, 'toggleterm.terminal')
  if ok and terminal_mod and terminal_mod.Terminal then
    local Terminal = terminal_mod.Terminal
    if copilot_term and copilot_term.bufnr and vim.api.nvim_buf_is_valid(copilot_term.bufnr) then
      local win = vim.fn.bufwinid(copilot_term.bufnr)
      if win == -1 then copilot_term:toggle() end
      copilot_term_buf = copilot_term.bufnr
      return true
    end

    copilot_term = Terminal:new {
      cmd = 'copilot',
      direction = 'vertical',
      hidden = true,
      close_on_exit = false,
      on_open = function(term) copilot_term_buf = term.bufnr end,
    }

    copilot_term:toggle()
    if copilot_term.bufnr and vim.api.nvim_buf_is_valid(copilot_term.bufnr) then
      copilot_term_buf = copilot_term.bufnr
      return true
    end

    vim.defer_fn(function()
      if copilot_term and copilot_term.bufnr and vim.api.nvim_buf_is_valid(copilot_term.bufnr) then copilot_term_buf = copilot_term.bufnr end
    end, 50)

    return true
  end

  if vim.fn.executable 'copilot' ~= 1 then
    vim.notify('copilot CLI not found in $PATH', vim.log.levels.ERROR)
    return false
  end

  vim.cmd 'botright vsplit'
  vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * 0.4))
  vim.cmd 'terminal copilot'
  copilot_term_buf = vim.api.nvim_get_current_buf()
  return true
end

function M.toggle()
  if copilot_term and copilot_term.toggle then
    local was_visible = copilot_term.bufnr and vim.api.nvim_buf_is_valid(copilot_term.bufnr) and vim.fn.bufwinid(copilot_term.bufnr) ~= -1
    copilot_term:toggle()
    if not was_visible and copilot_term.bufnr and vim.api.nvim_buf_is_valid(copilot_term.bufnr) then focus_terminal_if_visible() end
    return
  end

  if copilot_term_buf and vim.api.nvim_buf_is_valid(copilot_term_buf) then
    local win = vim.fn.bufwinid(copilot_term_buf)
    if win ~= -1 then
      vim.api.nvim_win_close(win, true)
      return
    end
  end

  if not ensure_copilot_term() then return end
  focus_terminal_if_visible()
end

function M.send_reference(reference)
  if not ensure_copilot_term() then return false end

  focus_terminal_if_visible()

  local buf = copilot_term_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    vim.notify('Copilot terminal buffer is not available', vim.log.levels.ERROR)
    return false
  end

  local ok, job_id = pcall(vim.api.nvim_buf_get_var, buf, 'terminal_job_id')
  if not ok or type(job_id) ~= 'number' then
    vim.notify('Copilot terminal is not ready', vim.log.levels.ERROR)
    return false
  end

  vim.fn.chansend(job_id, reference .. '\n')
  return true
end

return M
