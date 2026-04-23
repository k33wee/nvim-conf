return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function() require('conform').format { async = true, lsp_format = 'fallback' } end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then return nil end
        return { timeout_ms = 500, lsp_format = 'fallback' }
      end,

      formatters_by_ft = {
        lua = { 'stylua' },
        python = function(bufnr)
          local conform = require('conform')
          if conform.get_formatter_info('ruff_format', bufnr).available then
            return { 'ruff_format', 'ruff_organize_imports' }
          elseif conform.get_formatter_info('black', bufnr).available then
            return { 'isort', 'black' }
          else
            return { 'isort' }
          end
        end,
        rust = { 'rustfmt' },
        markdown = { 'prettier' },
        json = { 'prettier' },
        jsonc = { 'prettier' },

        -- We define the function inside the table directly or reference it
        javascript = function(bufnr) return get_js_formatter(bufnr) end,
        typescript = function(bufnr) return get_js_formatter(bufnr) end,
        javascriptreact = function(bufnr) return get_js_formatter(bufnr) end,
        typescriptreact = function(bufnr) return get_js_formatter(bufnr) end,
        vue = function(bufnr) return get_js_formatter(bufnr) end,
      },
    },
    config = function(_, opts)
      -- Helper function: Returns {"eslint_d"} or {"prettier"}
      get_js_formatter = function(bufnr)
        local has_eslint = vim.fs.find(
          { '.eslintrc', '.eslintrc.js', '.eslintrc.json', 'eslint.config.js', 'eslint.config.mjs' },
          { upward = true, path = vim.api.nvim_buf_get_name(bufnr) }
        )[1] ~= nil

        if has_eslint then
          -- Check if eslint_d is actually installed in Mason
          local ok = require('conform').get_formatter_info('eslint_d', bufnr).available
          if ok then return { 'eslint_d' } end
        end

        -- Fallback to standard prettier (since your log shows it is ready)
        return { 'prettier' }
      end

      require('conform').setup(opts)
    end,
  },
}
