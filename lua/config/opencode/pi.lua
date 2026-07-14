local M = {}

M.executable = 'pi'
M.model = 'openrouter/free'
M.thinking = 'minimal'

function M.args() return { M.executable, '--model', M.model, '--thinking', M.thinking } end

function M.print_args(system_prompt, prompt)
  local args = M.args()
  vim.list_extend(args, {
    '--print',
    '--no-session',
    '--no-context-files',
    '--no-tools',
    '--no-extensions',
    '--no-skills',
    '--no-prompt-templates',
    '--no-themes',
    '--system-prompt',
    system_prompt,
    prompt,
  })
  return args
end

return M
