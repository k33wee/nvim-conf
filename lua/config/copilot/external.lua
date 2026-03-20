local M = {}

local function external_copilot_session_name()
  local cwd = vim.fn.getcwd()
  local digest = vim.fn.sha256(cwd):sub(1, 12)
  local tail = vim.fn.fnamemodify(cwd, ':t'):gsub('[^%w]+', '-')
  if tail == '' then tail = 'root' end
  return string.format('copilot-%s-%s', tail, digest), cwd
end

local function tmux_session_exists(session_name)
  vim.fn.system { 'tmux', 'has-session', '-t', session_name }
  return vim.v.shell_error == 0
end

local function ensure_external_copilot_session()
  if vim.fn.executable 'tmux' ~= 1 then
    vim.notify('tmux is required for the external Copilot workflow', vim.log.levels.ERROR)
    return nil, nil, nil
  end

  if vim.fn.executable 'copilot' ~= 1 then
    vim.notify('copilot CLI not found in $PATH', vim.log.levels.ERROR)
    return nil, nil, nil
  end

  local session_name, cwd = external_copilot_session_name()
  if tmux_session_exists(session_name) then return session_name, cwd, false end

  local command = { 'tmux', 'new-session', '-d', '-s', session_name, '-c', cwd, 'copilot', '--alt-screen' }
  local job_id = vim.fn.jobstart(command, { cwd = cwd, detach = true })
  if job_id <= 0 then
    vim.notify('Failed to start external Copilot session', vim.log.levels.ERROR)
    return nil, nil, nil
  end

  return session_name, cwd, true
end

local function build_external_terminal_command(command_args, cwd)
  local sysname = vim.uv.os_uname().sysname
  if sysname == 'Darwin' then return nil, cwd end

  local launchers = {
    {
      executable = 'cosmic-term',
      build = function(args)
        local cmd = { 'cosmic-term', '--title', 'Copilot CLI', '--working-directory', cwd, '--command' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    },
    {
      executable = 'kitty',
      build = function(args)
        local cmd = { 'kitty', '--title', 'Copilot CLI', '--directory', cwd }
        vim.list_extend(cmd, args)
        return cmd
      end,
    },
    {
      executable = 'wezterm',
      build = function(args)
        local cmd = { 'wezterm', 'start', '--cwd', cwd, '--', 'sh', '-lc', 'exec "$@"', 'sh' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    },
    {
      executable = 'alacritty',
      build = function(args)
        local cmd = { 'alacritty', '--title', 'Copilot CLI', '--working-directory', cwd, '-e' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    },
    {
      executable = 'ghostty',
      build = function(args)
        local cmd = { 'ghostty', '--title=Copilot CLI', '--working-directory=' .. cwd, '-e' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    },
    {
      executable = 'foot',
      build = function(args)
        local cmd = { 'foot', '--title', 'Copilot CLI', '--working-directory', cwd }
        vim.list_extend(cmd, args)
        return cmd
      end,
    },
    {
      executable = 'gnome-terminal',
      build = function(args)
        local cmd = { 'gnome-terminal', '--title=Copilot CLI', '--working-directory=' .. cwd, '--' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    },
    {
      executable = 'konsole',
      build = function(args)
        local cmd = { 'konsole', '--workdir', cwd, '-p', 'tabtitle=Copilot CLI', '-e' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    },
    {
      executable = 'xterm',
      build = function(args)
        local cmd = {
          'xterm',
          '-title',
          'Copilot CLI',
          '-bg',
          '#11111b',
          '-fg',
          '#cdd6f4',
          '-fa',
          'Monospace',
          '-fs',
          '11',
          '-e',
        }
        vim.list_extend(cmd, args)
        return cmd
      end,
    },
  }

  local configured_terminal = vim.g.copilot_external_terminal
  if type(configured_terminal) == 'string' and configured_terminal ~= '' then
    for _, launcher in ipairs(launchers) do
      if launcher.executable == configured_terminal then return launcher.build(command_args), cwd end
    end
    vim.notify(string.format('Unsupported copilot external terminal: %s', configured_terminal), vim.log.levels.ERROR)
    return nil, nil
  end

  for _, launcher in ipairs(launchers) do
    if vim.fn.executable(launcher.executable) == 1 then return launcher.build(command_args), cwd end
  end

  return nil, nil
end

local function escape_applescript_string(value) return value:gsub('\\', '\\\\'):gsub('"', '\\"') end

local function open_macos_tmux_viewer(session_name, cwd)
  if vim.fn.executable 'osascript' ~= 1 then
    vim.notify('osascript is required to open Terminal.app on macOS', vim.log.levels.ERROR)
    return false
  end

  local apple_script = {
    'set projectDir to "' .. escape_applescript_string(cwd) .. '"',
    'set sessionName to "' .. escape_applescript_string(session_name) .. '"',
    'tell application "Terminal"',
    '  activate',
    '  do script "cd " & quoted form of projectDir & "; exec tmux attach-session -t " & quoted form of sessionName',
    'end tell',
  }
  local command = { 'osascript' }
  for _, line in ipairs(apple_script) do
    table.insert(command, '-e')
    table.insert(command, line)
  end

  local job_id = vim.fn.jobstart(command, { cwd = cwd, detach = true })
  if job_id <= 0 then
    vim.notify('Failed to open Terminal.app for Copilot', vim.log.levels.ERROR)
    return false
  end

  return true
end

local function type_in_external_copilot_session(session_name, input)
  local job_id = vim.fn.jobstart({ 'tmux', 'send-keys', '-t', session_name, '-l', input }, { detach = true })
  if job_id <= 0 then
    vim.notify('Failed to send text to external Copilot session', vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.open(opts)
  opts = opts or {}
  local session_name, cwd, created = ensure_external_copilot_session()
  if not session_name then return end

  local should_open_viewer = created or opts.open_existing ~= false
  local sysname = vim.uv.os_uname().sysname

  if should_open_viewer then
    if sysname == 'Darwin' then
      if not open_macos_tmux_viewer(session_name, cwd) then return end
    else
      local command, launch_cwd = build_external_terminal_command({ 'tmux', 'attach-session', '-t', session_name }, cwd)
      if not command then
        vim.notify(
          'No supported external terminal found. Set vim.g.copilot_external_terminal to one of: cosmic-term, kitty, wezterm, alacritty, ghostty, foot, gnome-terminal, konsole, xterm',
          vim.log.levels.ERROR
        )
        return
      end

      local job_id = vim.fn.jobstart(command, { cwd = launch_cwd, detach = true })
      if job_id <= 0 then
        vim.notify('Failed to open an external terminal for Copilot', vim.log.levels.ERROR)
        return
      end
    end
  end

  if opts.initial_prompt and opts.initial_prompt ~= '' then
    vim.defer_fn(function() type_in_external_copilot_session(session_name, opts.initial_prompt) end, created and 800 or 120)
    vim.notify('Inserted Copilot range reference into the external session', vim.log.levels.INFO)
    return
  end

  if created then
    vim.notify('Opened a new external Copilot session', vim.log.levels.INFO)
    return
  end

  vim.notify('Opened the existing external Copilot session', vim.log.levels.INFO)
end

return M
