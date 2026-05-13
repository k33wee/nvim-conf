local M = {}

function M.get_visual_line_range()
  local mode = vim.fn.mode()
  local start_row, end_row

  if mode == 'v' or mode == 'V' or mode == '\22' then
    start_row = vim.fn.line 'v'
    end_row = vim.fn.line '.'
  else
    local start_pos = vim.fn.getpos "'<"
    local end_pos = vim.fn.getpos "'>"
    start_row = start_pos[2]
    end_row = end_pos[2]
  end

  if start_row == 0 or end_row == 0 then return nil, nil end
  if start_row > end_row then
    start_row, end_row = end_row, start_row
  end

  return start_row, end_row
end

function M.file_line_reference(start_line, end_line)
  local full_path = vim.api.nvim_buf_get_name(0)
  if full_path == '' then return nil end

  local rel_path = vim.fn.fnamemodify(full_path, ':.')
  return string.format('@%s L%d-%d', rel_path, start_line, end_line)
end

function M.get_visual_reference()
  local start_line, end_line = M.get_visual_line_range()
  if not start_line or not end_line then
    vim.notify('No visual selection found', vim.log.levels.WARN)
    return nil
  end

  local reference = M.file_line_reference(start_line, end_line)
  if not reference then
    vim.notify('Buffer has no file path', vim.log.levels.WARN)
    return nil
  end

  return reference .. ' '
end

function M.leave_visual_mode()
  local esc = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
  vim.api.nvim_feedkeys(esc, 'nx', false)
end

return M
