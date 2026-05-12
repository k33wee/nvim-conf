local M = {}

local function launcher_name_from_command(command)
  if type(command) ~= 'string' or command == '' then return nil end
  return vim.fn.fnamemodify(command, ':t')
end

local function launcher_for_name(name, cwd)
  if name == 'cosmic-term' then
    return {
      executable = 'cosmic-term',
      build = function(args)
        local cmd = { 'cosmic-term', '--title', 'OpenCode CLI', '--working-directory', cwd, '--command' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    }
  end

  if name == 'kitty' then
    return {
      executable = 'kitty',
      build = function(args)
        local cmd = { 'kitty', '--title', 'OpenCode CLI', '--directory', cwd }
        vim.list_extend(cmd, args)
        return cmd
      end,
    }
  end

  if name == 'wezterm' then
    return {
      executable = 'wezterm',
      build = function(args)
        local cmd = { 'wezterm', 'start', '--cwd', cwd, '--', 'sh', '-lc', 'exec "$@"', 'sh' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    }
  end

  if name == 'alacritty' then
    return {
      executable = 'alacritty',
      build = function(args)
        local cmd = { 'alacritty', '--title', 'OpenCode CLI', '--working-directory', cwd, '-e' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    }
  end

  if name == 'ghostty' then
    return {
      executable = 'ghostty',
      build = function(args)
        local cmd = { 'ghostty', '--title=OpenCode CLI', '--working-directory=' .. cwd, '-e' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    }
  end

  if name == 'foot' then
    return {
      executable = 'foot',
      build = function(args)
        local cmd = { 'foot', '--title', 'OpenCode CLI', '--working-directory', cwd }
        vim.list_extend(cmd, args)
        return cmd
      end,
    }
  end

  if name == 'gnome-terminal' then
    return {
      executable = 'gnome-terminal',
      build = function(args)
        local cmd = { 'gnome-terminal', '--title=OpenCode CLI', '--working-directory=' .. cwd, '--' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    }
  end

  if name == 'konsole' then
    return {
      executable = 'konsole',
      build = function(args)
        local cmd = { 'konsole', '--workdir', cwd, '-p', 'tabtitle=OpenCode CLI', '-e' }
        vim.list_extend(cmd, args)
        return cmd
      end,
    }
  end

  if name == 'xterm' then
    return {
      executable = 'xterm',
      build = function(args)
        local cmd = {
          'xterm',
          '-title',
          'OpenCode CLI',
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
    }
  end

  return nil
end

local function detect_current_terminal()
  local terminal_env = launcher_name_from_command(vim.env.TERMINAL)
  if terminal_env then
    if launcher_for_name(terminal_env, '') then return terminal_env end
  end

  if vim.env.ALACRITTY_WINDOW_ID then return 'alacritty' end
  if vim.env.KITTY_WINDOW_ID or vim.env.KITTY_PID then return 'kitty' end
  if vim.env.WEZTERM_PANE then return 'wezterm' end
  if vim.env.GHOSTTY_RESOURCES_DIR or vim.env.GHOSTTY_BIN_DIR then return 'ghostty' end
  if vim.env.FOOT_SESSION then return 'foot' end
  if vim.env.GNOME_TERMINAL_SCREEN then return 'gnome-terminal' end
  if vim.env.KONSOLE_VERSION then return 'konsole' end

  return nil
end

local function external_opencode_session_name()
  local cwd = vim.fn.getcwd()
  local digest = vim.fn.sha256(cwd):sub(1, 12)
  local tail = vim.fn.fnamemodify(cwd, ':t'):gsub('[^%w]+', '-')
  if tail == '' then tail = 'root' end
  return string.format('opencode-%s-%s', tail, digest), cwd
end

local function tmux_session_exists(session_name)
  vim.fn.system { 'tmux', 'has-session', '-t', session_name }
  return vim.v.shell_error == 0
end

local function ensure_external_opencode_session()
  if vim.fn.executable 'tmux' ~= 1 then
    vim.notify('tmux is required for the external OpenCode workflow', vim.log.levels.ERROR)
    return nil, nil, nil
  end

  if vim.fn.executable 'opencode' ~= 1 then
    vim.notify('opencode CLI not found in $PATH', vim.log.levels.ERROR)
    return nil, nil, nil
  end

  local session_name, cwd = external_opencode_session_name()
  if tmux_session_exists(session_name) then return session_name, cwd, false end

  local command = { 'tmux', 'new-session', '-d', '-s', session_name, '-c', cwd, 'opencode', '--model', 'github-copilot/gpt-4.1' }
  local job_id = vim.fn.jobstart(command, { cwd = cwd, detach = true })
  if job_id <= 0 then
    vim.notify('Failed to start external OpenCode session', vim.log.levels.ERROR)
    return nil, nil, nil
  end

  return session_name, cwd, true
end

local function build_external_terminal_command(command_args, cwd)
  local sysname = vim.uv.os_uname().sysname
  if sysname == 'Darwin' then return nil, cwd end

  local launchers = {
    launcher_for_name('cosmic-term', cwd),
    launcher_for_name('kitty', cwd),
    launcher_for_name('wezterm', cwd),
    launcher_for_name('alacritty', cwd),
    launcher_for_name('ghostty', cwd),
    launcher_for_name('foot', cwd),
    launcher_for_name('gnome-terminal', cwd),
    launcher_for_name('konsole', cwd),
    launcher_for_name('xterm', cwd),
  }

  local configured_terminal = vim.g.opencode_external_terminal
  if type(configured_terminal) == 'string' and configured_terminal ~= '' then
    for _, launcher in ipairs(launchers) do
      if launcher.executable == configured_terminal then return launcher.build(command_args), cwd end
    end
    vim.notify(string.format('Unsupported opencode external terminal: %s', configured_terminal), vim.log.levels.ERROR)
    return nil, nil
  end

  local detected_terminal = detect_current_terminal()
  if detected_terminal then
    local launcher = launcher_for_name(detected_terminal, cwd)
    if launcher and vim.fn.executable(launcher.executable) == 1 then return launcher.build(command_args), cwd end
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
    vim.notify('Failed to open Terminal.app for OpenCode', vim.log.levels.ERROR)
    return false
  end

  return true
end

local function type_in_external_opencode_session(session_name, input)
  local job_id = vim.fn.jobstart({ 'tmux', 'send-keys', '-t', session_name, '-l', input }, { detach = true })
  if job_id <= 0 then
    vim.notify('Failed to send text to external OpenCode session', vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.open(opts)
  opts = opts or {}
  local session_name, cwd, created = ensure_external_opencode_session()
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
          'No supported external terminal found. Set vim.g.opencode_external_terminal to one of: cosmic-term, kitty, wezterm, alacritty, ghostty, foot, gnome-terminal, konsole, xterm',
          vim.log.levels.ERROR
        )
        return
      end

      local job_id = vim.fn.jobstart(command, { cwd = launch_cwd, detach = true })
      if job_id <= 0 then
        vim.notify('Failed to open an external terminal for OpenCode', vim.log.levels.ERROR)
        return
      end
    end
  end

  if opts.initial_prompt and opts.initial_prompt ~= '' then
    vim.defer_fn(function() type_in_external_opencode_session(session_name, opts.initial_prompt) end, created and 800 or 120)
    vim.notify('Inserted OpenCode range reference into the external session', vim.log.levels.INFO)
    return
  end

  if created then
    vim.notify('Opened a new external OpenCode session', vim.log.levels.INFO)
    return
  end

  vim.notify('Opened the existing external OpenCode session', vim.log.levels.INFO)
end

return M
