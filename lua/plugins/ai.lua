local inline_completion_models = { 'openrouter/free' }
local default_completion_model = inline_completion_models[1]
local inline_completion_reasoning_effort = 'minimal'
local prompt_model = 'gemma4:e4b'
local completion_model = default_completion_model
local completion_context_window = 8000
local completion_request_timeout = 4
local completion_throttle = 1500
local completion_debounce = 600

local function get_pi_openrouter_api_key()
  local auth_path = vim.fn.expand '~/.pi/agent/auth.json'
  local ok, lines = pcall(vim.fn.readfile, auth_path)
  if not ok or not lines or #lines == 0 then return nil end

  local ok_decode, auth = pcall(vim.json.decode, table.concat(lines, '\n'))
  if not ok_decode or type(auth) ~= 'table' then return nil end

  local api_key = auth.openrouter
  if type(api_key) == 'table' then api_key = api_key.key end
  if type(api_key) == 'string' and api_key ~= '' then return api_key end

  return nil
end

local function get_openrouter_api_key()
  if type(vim.env.OPENROUTER_API_KEY) == 'string' and vim.env.OPENROUTER_API_KEY ~= '' then return vim.env.OPENROUTER_API_KEY end

  return get_pi_openrouter_api_key()
end

local function set_inline_completion_model(model)
  completion_model = model

  local ok, minuet = pcall(require, 'minuet')
  if not ok or not minuet.config then return end

  minuet.config.provider = 'openai_compatible'
  minuet.config.provider_options.openai_compatible.model = model
end

local function create_ai_commands()
  vim.api.nvim_create_user_command('CheckInlineCompletionProvider', function()
    local has_env_key = type(vim.env.OPENROUTER_API_KEY) == 'string' and vim.env.OPENROUTER_API_KEY ~= ''
    local has_pi_auth_key = get_pi_openrouter_api_key() ~= nil
    local has_key = has_env_key or has_pi_auth_key
    local lines = {
      'Inline completion provider: OpenRouter',
      'model: ' .. completion_model,
      'reasoning effort: ' .. inline_completion_reasoning_effort,
      'OPENROUTER_API_KEY: ' .. (has_env_key and 'set' or 'missing'),
      'Pi OpenRouter auth: ' .. (has_pi_auth_key and 'set' or 'missing'),
    }

    local level = has_key and vim.log.levels.INFO or vim.log.levels.WARN
    vim.notify(table.concat(lines, '\n'), level, { title = 'CheckInlineCompletionProvider' })
  end, { desc = 'Check OpenRouter inline completion setup' })

  vim.api.nvim_create_user_command('SelectInlineModel', function()
    vim.ui.select(inline_completion_models, {
      prompt = 'Select inline completion model:',
      format_item = function(item)
        if item == completion_model then return item .. ' (current)' end

        return item
      end,
    }, function(choice)
      if not choice then return end

      set_inline_completion_model(choice)
      vim.notify('Inline completion model set to ' .. choice, vim.log.levels.INFO)
    end)
  end, { desc = 'Select OpenRouter model for inline completion' })
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
        provider = 'openai_compatible',
        n_completions = 3,
        context_window = completion_context_window,
        request_timeout = completion_request_timeout,
        throttle = completion_throttle,
        debounce = completion_debounce,
        notify = 'error',
        add_single_line_entry = false,
        provider_options = {
          openai_compatible = {
            name = 'OpenRouter',
            end_point = 'https://openrouter.ai/api/v1/chat/completions',
            model = completion_model,
            api_key = get_openrouter_api_key,
            stream = true,
            optional = {
              max_tokens = 56,
              top_p = 0.9,
              provider = {
                sort = 'throughput',
              },
              reasoning = {
                effort = inline_completion_reasoning_effort,
              },
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
