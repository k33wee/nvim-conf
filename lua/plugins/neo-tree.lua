local media = require 'config.media'

return {
  {
    'nvim-neo-tree/neo-tree.nvim',
    version = '*',
    cmd = 'Neotree',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    keys = {
      { '<leader>e', '<cmd>Neotree toggle<CR>', desc = 'Explorer (Neo-tree)' },
      { '\\', '<cmd>Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
    },
    opts = {
      commands = {
        open_with_system_app = function(state) media.open_neotree_node(state) end,
      },
      window = {
        mappings = {
          ['<space>'] = 'none',
          ['O'] = 'open_with_system_app',
        },
      },
      filesystem = {
        follow_current_file = { enabled = true },
        window = {
          mappings = {
            ['\\'] = 'close_window',
            ['O'] = 'open_with_system_app',
          },
        },
      },
    },
    init = function()
      vim.api.nvim_create_user_command('OpenWithSystemApp', function(opts) media.open(opts.args ~= '' and opts.args or nil) end, {
        nargs = '?',
        complete = 'file',
        desc = 'Open a file with the system default application',
      })

      vim.keymap.set('n', '<leader>mo', media.open, { desc = '[M]edia [O]pen with system app' })

      vim.api.nvim_create_autocmd('VimEnter', {
        desc = 'Open Neo-tree when opening a directory',
        group = vim.api.nvim_create_augroup('neotree-auto-open', { clear = true }),
        callback = function(data)
          local directory = vim.fn.isdirectory(data.file) == 1
          if not directory then return end
          local dir = vim.fn.fnamemodify(data.file, ':p')
          vim.cmd.cd(dir)
          vim.schedule(function() vim.cmd('Neotree current dir=' .. vim.fn.fnameescape(dir)) end)
        end,
      })
    end,
  },
}
