local M = {}

local function normalize_path(path)
  if not path or path == '' then return nil end

  local expanded = vim.fn.expand(path)
  if expanded == '' then return nil end

  return vim.fs.normalize(vim.fn.fnamemodify(expanded, ':p'))
end

local function format_open_error(cmd, result)
  if not cmd or not result or result.code == 0 then return nil end

  return ('vim.ui.open: command %s (%d): %s'):format(result.code == 124 and 'timeout' or 'failed', result.code, vim.inspect(cmd.cmd))
end

function M.has_imagemagick() return vim.fn.executable 'magick' == 1 or vim.fn.executable 'convert' == 1 end

function M.image_backend()
  local term = (vim.env.TERM or ''):lower()
  local term_program = (vim.env.TERM_PROGRAM or ''):lower()

  if vim.env.KITTY_WINDOW_ID or term:find('kitty', 1, true) then return 'kitty' end
  if term_program == 'wezterm' or term_program == 'ghostty' then return 'kitty' end
  if vim.fn.executable 'ueberzugpp' == 1 then return 'ueberzug' end

  return nil
end

function M.open(path)
  local target = normalize_path(path or vim.api.nvim_buf_get_name(0))
  if not target then
    vim.notify('No file path available to open with the system app.', vim.log.levels.WARN)
    return
  end

  local cmd, err = vim.ui.open(target)
  if not err then err = format_open_error(cmd, cmd and cmd:wait(1000) or nil) end
  if err then vim.notify(err, vim.log.levels.ERROR) end
end

function M.open_neotree_node(state)
  local node = state.tree and state.tree:get_node()
  if not node or node.type ~= 'file' then
    vim.notify('Select a file to open with the system app.', vim.log.levels.WARN)
    return
  end

  M.open(node:get_id())
end

return M
