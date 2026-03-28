return {
  {
    'OXY2DEV/markview.nvim',
    ft = { 'markdown', 'quarto', 'rmd' },

    -- Completion for `blink.cmp`
    -- dependencies = { "saghen/blink.cmp" },
  },
  {
    'toppair/peek.nvim',
    build = function()
      vim.system({ 'deno', 'task', 'build:fast' }, { cwd = vim.fn.stdpath 'data' .. '/lazy/peek.nvim' }):wait()
    end,
    event = 'VeryLazy',
    keys = {
      {
        '<leader>mp',
        function() vim.cmd.PeekOpen() end,
        desc = '[M]arkdown [P]review',
      },
      {
        '<leader>mP',
        function() vim.cmd.PeekClose() end,
        desc = '[M]arkdown preview close',
      },
    },
    config = function()
      local function ensure_peek_assets()
        local plugin_dir = vim.fn.stdpath 'data' .. '/lazy/peek.nvim'
        local bundle_path = plugin_dir .. '/public/main.bundle.js'

        if vim.uv.fs_stat(bundle_path) then return true end
        if vim.fn.executable 'deno' ~= 1 then
          vim.notify('peek.nvim requires Deno to build its preview assets.', vim.log.levels.ERROR)
          return false
        end

        vim.notify('Building peek.nvim preview assets...', vim.log.levels.INFO)
        local result = vim.system({ 'deno', 'task', 'build:fast' }, { cwd = plugin_dir, text = true }):wait()
        if result.code ~= 0 then
          vim.notify(result.stderr ~= '' and result.stderr or 'Failed to build peek.nvim assets.', vim.log.levels.ERROR)
          return false
        end

        return vim.uv.fs_stat(bundle_path) ~= nil
      end

      local ok, peek = pcall(require, 'peek')
      if not ok then
        vim.schedule(function() vim.notify_once('peek.nvim is unavailable. Run :Lazy build peek.nvim after installing Deno.', vim.log.levels.WARN) end)
        return
      end

      peek.setup {
        auto_load = false,
        close_on_bdelete = true,
        syntax = true,
        theme = vim.o.background,
        update_on_change = true,
        app = 'browser',
        filetype = { 'markdown', 'quarto', 'rmd' },
      }

      vim.api.nvim_create_user_command('PeekOpen', function()
        if not ensure_peek_assets() then return end
        peek.open()
      end, { desc = 'Open Markdown preview' })
      vim.api.nvim_create_user_command('PeekClose', peek.close, { desc = 'Close Markdown preview' })
    end,
  },
}
