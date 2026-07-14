local M = {}
local pi = require 'config.opencode.pi'

local commit_message_generation_in_progress = false

local function reset_guard() commit_message_generation_in_progress = false end

local function schedule_guard_reset() vim.defer_fn(reset_guard, 60000) end

local function system_prompt()
  return table.concat({
    'You are a conventional commit message generator.',
    'Generate a one-line commit message from the provided diff.',
    'Use the format: <type>: <short summary>',
    'Types: feat fix refactor chore docs style test perf',
    'Reply with only the commit message, nothing else.',
  }, '\n')
end

--- Truncate a diff so it fits within the model's context budget.
--- @param diff string
--- @param max_chars integer
--- @param line_count integer number of original lines (for the summary)
--- @return string
local function truncate_diff(diff, max_chars, line_count)
  if #diff <= max_chars then return diff end
  local lines = vim.split(diff, '\n', { plain = true })
  local result = {}
  local total = 0
  for _, line in ipairs(lines) do
    if total + #line + 1 > max_chars then break end
    table.insert(result, line)
    total = total + #line + 1
  end
  result[#result] = result[#result] .. ('\n... (%d of %d lines shown)'):format(#result, line_count)
  return table.concat(result, '\n')
end

---@param prompt string
---@param callback fun(message: string?, err: string?)
local function query_pi(prompt, callback)
  vim.system(pi.print_args(system_prompt(), prompt), { text = true, timeout = 60000 }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local err = vim.trim(table.concat({ result.stderr or '', result.stdout or '' }, '\n'))
        callback(nil, err ~= '' and err or 'Pi command failed')
        return
      end

      local message = vim.trim(result.stdout or '')
      message = message:gsub('^```%w*%s*', ''):gsub('%s*```$', '')
      message = vim.split(message, '\n', { plain = true, trimempty = true })[1] or ''
      if message == '' then
        callback(nil, 'empty content in Pi response')
        return
      end

      callback(vim.trim(message))
    end)
  end)
end

function M.generate()
  if vim.fn.executable(pi.executable) ~= 1 then
    vim.notify('Pi CLI not found in $PATH', vim.log.levels.ERROR)
    return
  end

  if commit_message_generation_in_progress then
    vim.notify('Commit message generation already in progress', vim.log.levels.WARN)
    return
  end

  commit_message_generation_in_progress = true
  schedule_guard_reset()
  vim.notify('Generating commit message...', vim.log.levels.INFO)

  vim.system({ 'git', 'diff', '--staged', '--no-color', '--no-ext-diff' }, { text = true }, function(diff_result)
    vim.schedule(function()
      if diff_result.code ~= 0 then
        commit_message_generation_in_progress = false
        vim.notify('Failed to read staged changes', vim.log.levels.ERROR)
        return
      end

      local staged_diff = vim.trim(diff_result.stdout or '')
      if staged_diff == '' then
        commit_message_generation_in_progress = false
        vim.notify('No staged changes found', vim.log.levels.WARN)
        return
      end

      local diff_lines = #vim.split(staged_diff, '\n', { plain = true })
      local truncated_diff = truncate_diff(staged_diff, 6000, diff_lines)
      local user_prompt = 'Staged diff:\n\n' .. truncated_diff

      query_pi(user_prompt, function(message, err)
        commit_message_generation_in_progress = false
        if err then
          vim.notify('Commit generation failed: ' .. err, vim.log.levels.ERROR)
          return
        end

        vim.fn.setreg('+', message)
        vim.fn.setreg('"', message)
        vim.notify('Commit message: ' .. message:gsub('\n.*', ''):sub(1, 80), vim.log.levels.INFO)
      end)
    end)
  end)
end

return M
