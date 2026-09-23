--[[
  Kickstart-style Neovim config.
  Single file for now; split into lua/ modules once this grows unwieldy.

  LSP servers, formatters, and build tooling (compiler, make, fd, ripgrep)
  are installed declaratively via NixOS (/etc/nixos/cfg/neovim.nix) rather
  than through Mason, since Mason's prebuilt binaries don't reliably run on
  NixOS's non-standard dynamic linker.
--]]

-- Set leader keys before any plugin loads, so mappings register correctly.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- [[ Options ]]
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.showmode = false -- statusline (mini.statusline) shows mode instead
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.inccommand = 'split'
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.confirm = true -- prompt to save instead of erroring on :q with unsaved changes

-- Popup-menu (not bottom-bar) rendering for cmdline completion, with fuzzy
-- matching: e.g. `:e <Tab>` lists cwd entries in a floating menu, `:e test/`
-- lists parent/test/, and typing further narrows the list live.
vim.opt.wildoptions = 'pum,fuzzy'

-- Default indentation: 4 spaces. vim-sleuth (below) overrides this per-buffer
-- when it detects an existing file's actual indent style.
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4

vim.api.nvim_create_autocmd('FileType', {
  desc = 'Use 2-space indent for Nix, matching nixfmt style',
  group = vim.api.nvim_create_augroup('nix-indent', { clear = true }),
  pattern = 'nix',
  callback = function()
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
  end,
})

-- Neovim's runtime maps *.x to the built-in "rpcgen" filetype (Sun RPC/XDR),
-- which isn't in use here. Remap it to a plain filetype name with no bundled
-- syntax/indent file, so a custom language under development can use the
-- extension without rpcgen's syntax highlighting fighting its own syntax.
vim.filetype.add { extension = { x = 'x-lang' } }

vim.api.nvim_create_autocmd('FileType', {
  desc = 'C-style auto-indent (and brace/paren matching) for .x files',
  group = vim.api.nvim_create_augroup('x-lang-indent', { clear = true }),
  pattern = 'x-lang',
  callback = function()
    vim.bo.cindent = true
  end,
})

-- Treesitter's html indentexpr doesn't reliably dedent a closing tag back to
-- its opening tag's level when splitting a line (verified: it over-indents),
-- so compute the split by hand from 'shiftwidth' instead, the same C-style
-- expansion mini.pairs already gives single-char pairs like {}/()/[].
vim.api.nvim_create_autocmd('FileType', {
  desc = 'C-style expand-and-indent when Enter is pressed between a tag and its matching close tag',
  group = vim.api.nvim_create_augroup('html-tag-indent', { clear = true }),
  pattern = 'html',
  callback = function(event)
    vim.keymap.set('i', '<CR>', function()
      local line = vim.api.nvim_get_current_line()
      local row, col = unpack(vim.api.nvim_win_get_cursor(0))
      local before, after = line:sub(1, col), line:sub(col + 1)
      if not (before:match '>$' and after:match '^</') then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'n', false)
        return
      end
      local base_indent = line:match '^%s*'
      local inner_indent = base_indent .. string.rep(' ', vim.fn.shiftwidth())
      vim.api.nvim_set_current_line(before)
      vim.api.nvim_buf_set_lines(0, row, row, false, { inner_indent, base_indent .. after })
      vim.api.nvim_win_set_cursor(0, { row + 1, #inner_indent })
    end, { buffer = event.buf, desc = 'Smart Enter between HTML tags' })
  end,
})

-- Sync system clipboard after startup (deferred so startup isn't slowed by clipboard tool checks)
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

-- [[ Keymaps ]]
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- <Left>/<Right> already navigate the cmdline completion popup natively.
-- Add <Up>/<Down> too, but only while the popup is open, so cmdline history
-- recall (their normal job) still works the rest of the time.
vim.keymap.set('c', '<Down>', function()
  return vim.fn.wildmenumode() == 1 and '<C-n>' or '<Down>'
end, { expr = true, desc = 'Next completion match (or recall newer history)' })
vim.keymap.set('c', '<Up>', function()
  return vim.fn.wildmenumode() == 1 and '<C-p>' or '<Up>'
end, { expr = true, desc = 'Previous completion match (or recall older history)' })

-- [[ Autocommands ]]
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- [[ Bootstrap lazy.nvim ]]
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Failed to clone lazy.nvim:\n' .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

-- [[ Plugins ]]
require('lazy').setup {

  'tpope/vim-sleuth', -- auto-detect indentation (tabstop/shiftwidth) per file

  { -- Adds git gutter signs and hunk navigation
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },

  { -- Shows pending keybindings in a popup
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {},
  },

  { -- Fuzzy finder
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
    },
    config = function()
      require('telescope').setup {
        extensions = { ['ui-select'] = { require('telescope.themes').get_dropdown() } },
      }
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })
      vim.keymap.set('n', '<leader>/', builtin.current_buffer_fuzzy_find, { desc = '[/] Fuzzy search in buffer' })
    end,
  },

  { -- Treesitter: better syntax highlighting, indentation, and text objects
    'nvim-treesitter/nvim-treesitter',
    branch = 'master', -- repo's default branch will switch to a rewritten 'main' later; pin per upstream README
    lazy = false, -- upstream README: this plugin does not support lazy-loading
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs',
    opts = {
      ensure_installed = { 'bash', 'c', 'html', 'lua', 'luadoc', 'nix', 'python', 'vim', 'vimdoc', 'markdown', 'query' },
      auto_install = true,
      highlight = { enable = true },
      -- c/cpp's indent queries mishandle expression_statement (e.g. a bare
      -- `printf(...);` call), causing inconsistent indent after such lines.
      -- Fall back to Neovim's built-in cindent for these, which doesn't
      -- have that bug.
      indent = { enable = true, disable = { 'c', 'cpp' } },
    },
  },

  { -- Auto-close and auto-rename HTML tags (treesitter-based)
    'windwp/nvim-ts-autotag',
    ft = 'html',
    opts = { opts = { enable_close = true, enable_rename = true, enable_close_on_slash = false } },
  },

  { -- LSP configuration
    'neovim/nvim-lspconfig',
    dependencies = { 'hrsh7th/cmp-nvim-lsp' },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
          map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
          map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
          map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
          map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
          map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
          map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
          map('K', vim.lsp.buf.hover, 'Hover Documentation')
          map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
        end,
      })

      -- Advertise nvim-cmp's completion capabilities to every server.
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      vim.lsp.config('*', { capabilities = capabilities })

      -- Per-language servers. All binaries below come from NixOS
      -- (see /etc/nixos/cfg/neovim.nix), not Mason.
      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            completion = { callSnippet = 'Replace' },
          },
        },
      })
      vim.lsp.config('nixd', {})
      vim.lsp.config('pyright', {})
      vim.lsp.config('clangd', {})
      vim.lsp.config('html', {})

      vim.lsp.enable { 'lua_ls', 'nixd', 'pyright', 'clangd', 'html' }
    end,
  },

  { -- VSCode Error Lens-style inline diagnostics
    'rachartier/tiny-inline-diagnostic.nvim',
    event = 'LspAttach',
    priority = 1000, -- must load before diagnostics are first shown
    opts = {
      options = {
        -- Defaults only render the diagnostic on the cursor's current line;
        -- this shows every visible line's diagnostic at once, like VSCode's Error Lens.
        multilines = { enabled = true, always_show = true },
        -- Defaults suppress diagnostics in insert mode; keep them visible there too.
        enable_on_insert = true,
      },
    },
    config = function(_, opts)
      require('tiny-inline-diagnostic').setup(opts)
      vim.diagnostic.config { virtual_text = false } -- avoid double display alongside tiny-inline-diagnostic
    end,
  },

  { -- On-demand formatting (<leader>f), no format-on-save
    'stevearc/conform.nvim',
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      -- No format_on_save: formatting only happens on-demand via <leader>f.
      formatters_by_ft = {
        lua = { 'stylua' },
        nix = { 'nixfmt' },
        python = { 'ruff_format' },
        c = { 'clang_format' },
      },
      formatters = {
        clang_format = {
          -- Without a project .clang-format file, clang-format defaults to
          -- the LLVM style (2-space indent), which fights the 4-space
          -- default set globally and confuses vim-sleuth on reopen.
          prepend_args = { '--style={BasedOnStyle: llvm, IndentWidth: 4}' },
        },
      },
    },
  },

  { -- Autocompletion
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    dependencies = {
      {
        'L3MON4D3/LuaSnip',
        build = (function()
          -- Only needed for regex-based snippet transforms; skipped without a C toolchain.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
      },
      'saadparwaiz1/cmp_luasnip',
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-buffer',
    },
    config = function()
      local cmp = require 'cmp'
      local luasnip = require 'luasnip'
      luasnip.config.setup {}

      cmp.setup {
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        -- noselect (not noinsert): with noinsert, Vim's native popup
        -- auto-highlights the first entry before cmp tracks any selection,
        -- so Tab (select_next_item) advances past it to the second entry.
        completion = { completeopt = 'menu,menuone,noselect' },
        mapping = cmp.mapping.preset.insert {
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<C-p>'] = cmp.mapping.select_prev_item(),
          ['<C-y>'] = cmp.mapping.confirm { select = true },
          ['<C-Space>'] = cmp.mapping.complete {},
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_locally_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'path' },
          { name = 'buffer' },
        },
      }
    end,
  },

  { -- Colorscheme
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    opts = {
      flavour = 'mocha',
      transparent_background = true, -- no nvim-painted bg; inherits the terminal's own
    },
    config = function(_, opts)
      require('catppuccin').setup(opts)
      vim.cmd.colorscheme 'catppuccin'
    end,
  },

  { -- Highlight TODO/NOTE/FIXME comments
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },

  { -- Small collection of independent editing utilities
    'echasnovski/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 } -- better text objects (e.g. dap, dip)
      require('mini.surround').setup() -- add/change/delete surrounding pairs (ys, cs, ds)
      require('mini.pairs').setup() -- auto-close (), [], {}, "", ''

      -- gitsigns' cached branch var doesn't populate for a repo with zero commits
      -- (unborn HEAD), and won't refresh if `git init` runs outside the buffer's
      -- own lifecycle events. Track the branch ourselves instead, so it's correct
      -- for that case and re-checked whenever it plausibly changed.
      local git_branch_cache = {}
      local function refresh_git_branch(bufnr)
        local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')
        if vim.fn.isdirectory(dir) == 0 then
          return
        end
        vim.system({ 'git', '-C', dir, 'branch', '--show-current' }, { text = true }, function(res)
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(bufnr) then
              return
            end
            git_branch_cache[bufnr] = (res.code == 0) and (vim.trim(res.stdout or '') ~= '' and vim.trim(res.stdout) or 'detached')
              or false
            vim.cmd.redrawstatus()
          end)
        end)
      end
      vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'ShellCmdPost', 'TermClose' }, {
        desc = 'Refresh statusline git branch cache',
        group = vim.api.nvim_create_augroup('statusline-git-branch', { clear = true }),
        callback = function(args)
          refresh_git_branch(args.buf or vim.api.nvim_get_current_buf())
        end,
      })

      local statusline = require 'mini.statusline'
      statusline.setup {
        content = {
          -- Mode, full file path, then git branch (or "No Git") and error/warn
          -- counts (always shown, even at zero) pushed to the right. Everything
          -- else (diff/lsp/fileinfo/location) dropped; git/diagnostics never
          -- disappear the way the built-in sections do.
          active = function()
            local mode, mode_hl = statusline.section_mode { trunc_width = 120 }

            local branch = git_branch_cache[vim.api.nvim_get_current_buf()]
            local git = branch and ('Git: ' .. branch) or 'No Git'

            local bufnr = vim.api.nvim_get_current_buf()
            local n_errors = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
            local n_warnings = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN })

            return statusline.combine_groups {
              { hl = mode_hl, strings = { mode } },
              { hl = 'MiniStatuslineFilename', strings = { '%F %m%r' } },
              '%=',
              { hl = 'MiniStatuslineGitBranch', strings = { git } },
              { hl = 'MiniStatuslineDiagError', strings = { 'E:' .. n_errors } },
              { hl = 'MiniStatuslineDiagWarn', strings = { 'W:' .. n_warnings } },
            }
          end,
        },
      }

      -- Flatten the whole bar to one continuous background: mode previously had
      -- its own colored block (Normal=blue, Insert=green, ...) and git/error/warn
      -- had no background of their own at all (showing the transparent terminal
      -- bg through as a "hole"). Re-derive each group's text color but pin every
      -- group's background to the bar's own bg, and redo it on every colorscheme
      -- change since the source colors (String/DiagnosticError/...) change too.
      local function flatten_statusline_bg()
        local bar_bg = vim.api.nvim_get_hl(0, { name = 'MiniStatuslineFilename' }).bg

        -- Mode groups are (dark fg, bright bg) badges by design (e.g. Normal =
        -- dark text on blue) — their bg is the color that identifies the mode,
        -- so use THAT as the new standalone text color, not their old fg.
        local function flatten_mode(name)
          local bg = vim.api.nvim_get_hl(0, { name = name }).bg
          vim.api.nvim_set_hl(0, name, { fg = bg, bg = bar_bg })
        end
        for _, name in ipairs {
          'MiniStatuslineModeNormal',
          'MiniStatuslineModeInsert',
          'MiniStatuslineModeVisual',
          'MiniStatuslineModeReplace',
          'MiniStatuslineModeCommand',
          'MiniStatuslineModeOther',
        } do
          flatten_mode(name)
        end

        -- Git/diagnostic groups already are standalone text colors; just pin bg.
        local function flatten_fg(name, fg_source)
          local fg = vim.api.nvim_get_hl(0, { name = fg_source }).fg
          vim.api.nvim_set_hl(0, name, { fg = fg, bg = bar_bg })
        end
        flatten_fg('MiniStatuslineGitBranch', 'String')
        flatten_fg('MiniStatuslineDiagError', 'DiagnosticError')
        flatten_fg('MiniStatuslineDiagWarn', 'DiagnosticWarn')
      end
      flatten_statusline_bg()
      vim.api.nvim_create_autocmd('ColorScheme', {
        desc = 'Keep statusline background flat across colorscheme changes',
        group = vim.api.nvim_create_augroup('statusline-flat-colors', { clear = true }),
        callback = flatten_statusline_bg,
      })
    end,
  },
}
