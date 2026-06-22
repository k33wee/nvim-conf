local sysname = vim.uv.os_uname().sysname
local is_macos = sysname == 'Darwin'

local default_completion_model = is_macos and 'qwen2.5-coder:7b' or 'qwen2.5-coder:3b'
local prompt_model = 'gemma4:e4b'
local completion_model = default_completion_model
local completion_context_window = is_macos and 1024 or 512
local completion_request_timeout = is_macos and 2.5 or 1.8
local completion_throttle = is_macos and 150 or 250
local completion_debounce = is_macos and 60 or 100

local function fetch_ollama_models()
  local result = vim
    .system({
      'curl',
      '-fsSL',
      'http://127.0.0.1:11434/api/tags',
    }, { text = true })
    :wait()

  if result.code ~= 0 then return nil, (result.stderr or 'failed to query Ollama'):gsub('%s+$', '') end

  local ok, body = pcall(vim.json.decode, result.stdout)
  if not ok or type(body) ~= 'table' or type(body.models) ~= 'table' then return nil, 'failed to decode Ollama model list' end

  local models = {}
  for _, model in ipairs(body.models) do
    if type(model) == 'table' and type(model.name) == 'string' then table.insert(models, model.name) end
  end

  table.sort(models)
  return models
end

local function set_inline_completion_model(model)
  completion_model = model

  local ok, minuet = pcall(require, 'minuet')
  if not ok or not minuet.config then return end

  minuet.config.provider = 'openai_fim_compatible'
  minuet.config.provider_options.openai_fim_compatible.model = model
end

local function create_ai_commands()
  vim.api.nvim_create_user_command('CheckOllamaModels', function()
    local models, err = fetch_ollama_models()
    if not models then
      vim.notify('Ollama model check failed: ' .. err, vim.log.levels.ERROR)
      return
    end

    local installed = {}
    for _, model in ipairs(models) do
      installed[model] = true
    end

    local expected_models = { prompt_model, default_completion_model }
    if completion_model ~= default_completion_model then table.insert(expected_models, completion_model) end

    local lines = {
      'Ollama models:',
      'inline completion: ' .. completion_model,
      'prompt workflows: ' .. prompt_model,
    }

    local missing = {}
    for _, model in ipairs(expected_models) do
      if installed[model] then
        table.insert(lines, 'installed: ' .. model)
      else
        table.insert(lines, 'missing: ' .. model)
        table.insert(missing, model)
      end
    end

    local level = #missing == 0 and vim.log.levels.INFO or vim.log.levels.WARN
    vim.notify(table.concat(lines, '\n'), level, { title = 'CheckOllamaModels' })
  end, { desc = 'Check local Ollama models for this setup' })

  vim.api.nvim_create_user_command('SelectInlineModel', function()
    local models, err = fetch_ollama_models()
    if not models then
      vim.notify('Unable to list Ollama models: ' .. err, vim.log.levels.ERROR)
      return
    end

    if #models == 0 then
      vim.notify('No local Ollama models found', vim.log.levels.WARN)
      return
    end

    vim.ui.select(models, {
      prompt = 'Select inline completion model:',
      format_item = function(item)
        if item == completion_model then return item .. ' (current)' end

        if item == default_completion_model then return item .. ' (recommended)' end

        return item
      end,
    }, function(choice)
      if not choice then return end

      set_inline_completion_model(choice)
      vim.notify('Inline completion model set to ' .. choice, vim.log.levels.INFO)
    end)
  end, { desc = 'Select local Ollama model for inline completion' })
end

return {
  {
    'milanglacier/minuet-ai.nvim',
    event = 'InsertEnter',
    dependencies = {
      'saghen/blink.cmp',
    },
    opts = function()
      return {
        provider = 'openai_fim_compatible',
        n_completions = 3,
        context_window = completion_context_window,
        request_timeout = completion_request_timeout,
        throttle = completion_throttle,
        debounce = completion_debounce,
        notify = 'error',
        add_single_line_entry = false,
        provider_options = {
          openai_fim_compatible = {
            name = 'Ollama',
            end_point = 'http://127.0.0.1:11434/v1/completions',
            model = completion_model,
            api_key = function() return 'ollama' end,
            stream = true,
            optional = {
              max_tokens = 32,
              top_p = 0.9,
              stop = { '\n\n' },
            },
          },
        },
        virtualtext = {
          auto_trigger_ft = { '*' },
          keymap = {
            next = '<M-n>',
            prev = '<M-p>',
            accept_line = '<M-l>',
          },
          show_on_completion_menu = false,
        },
      }
    end,
    config = function(_, opts)
      require('minuet').setup(opts)
      create_ai_commands()

      local minuet = require 'minuet.virtualtext'
      local blink = require 'blink.cmp'

      vim.keymap.set('i', '<Tab>', function()
        if minuet.action.is_visible() then
          minuet.action.accept()
          return ''
        end

        if blink.snippet_active { direction = 1 } then
          blink.snippet_forward()
          return ''
        end

        return '<Tab>'
      end, { expr = true, silent = true, desc = 'Accept AI suggestion or tab' })
    end,
    keys = {
      { '<leader>ae', '<cmd>Minuet virtualtext enable<CR>', desc = 'AI ghost text enable' },
      { '<leader>ad', '<cmd>Minuet virtualtext disable<CR>', desc = 'AI ghost text disable' },
      { '<leader>at', '<cmd>Minuet virtualtext toggle<CR>', desc = 'AI ghost text toggle' },
    },
  },
  {
    'nomnivore/ollama.nvim',
    cmd = { 'Ollama', 'OllamaModel', 'OllamaServe', 'OllamaServeStop' },
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    keys = {
      {
        '<leader>oo',
        ":<C-u>lua require('ollama').prompt()<CR>",
        desc = 'Ollama prompt menu',
        mode = { 'n', 'v' },
      },
      {
        '<leader>or',
        ":<C-u>lua require('ollama').prompt('Refactor_Code')<CR>",
        desc = 'Ollama refactor code',
        mode = { 'n', 'v' },
      },
      {
        '<leader>oe',
        ":<C-u>lua require('ollama').prompt('Explain_Code')<CR>",
        desc = 'Ollama explain code',
        mode = { 'n', 'v' },
      },
      {
        '<leader>oc',
        ":<C-u>lua require('ollama').prompt('Custom_Workflow')<CR>",
        desc = 'Ollama custom workflow',
        mode = { 'n', 'v' },
      },
    },
    opts = {
      model = prompt_model,
      url = 'http://127.0.0.1:11434',
      serve = {
        on_start = false,
        command = 'ollama',
        args = { 'serve' },
        stop_command = 'pkill',
        stop_args = { '-SIGTERM', 'ollama' },
      },
      prompts = {
        Explain_Code = {
          prompt = table.concat({
            'Explain the selected $ftype code clearly and concisely.',
            'Focus on intent, control flow, important data structures, and any risks.',
            '',
            '$sel',
          }, '\n'),
          model = prompt_model,
          action = 'display',
        },
        Refactor_Code = {
          prompt = table.concat({
            'Refactor the selected $ftype code.',
            'Preserve behavior, improve readability, and keep the diff small.',
            'Return only the final code in a fenced ```$ftype block.',
            '',
            '$sel',
          }, '\n'),
          model = prompt_model,
          action = 'display_replace',
          extract = '```$ftype\n(.-)```',
          options = {
            temperature = 0.2,
          },
        },
        Custom_Workflow = {
          prompt = table.concat({
            '$input',
            '',
            'Use the following $ftype context:',
            '$sel',
          }, '\n'),
          input_label = 'Prompt: ',
          model = prompt_model,
          action = 'display',
        },
      },
    },
  },
}
