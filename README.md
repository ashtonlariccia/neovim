# Neovim config

Single-file `init.lua`, kickstart-style. Plugins are managed by
[lazy.nvim](https://github.com/folke/lazy.nvim), which self-bootstraps on
first launch — no manual plugin install step needed.

## Setup on a new device

1. Place `init.lua` at `~/.config/nvim/init.lua`.
2. Launch `nvim`. lazy.nvim clones itself and installs all plugins
   automatically.

## What does NOT transfer with this repo

`init.lua` only configures Neovim itself. It assumes the following are
already present on the host; without them, Neovim still starts and plugins
still install, but specific features silently stop working.

### External CLI tools

| Tool | Needed for | Symptom if missing |
|---|---|---|
| `git` | lazy.nvim bootstrap, gitsigns, statusline git branch | Plugin manager fails to install; no git info in statusline |
| `make` + a C compiler (`cc`/`gcc`) | `telescope-fzf-native.nvim` build step, Treesitter parser builds (`:TSUpdate`) | Native fzf sorter unavailable (falls back to slower Lua matcher); parsers fail to compile, no highlighting/indent for those languages |
| `ripgrep` (`rg`) | Telescope live grep / grep-string | `<leader>sg`, `<leader>sw` error out |
| `fd` | Telescope file finding (optional but expected) | Slower/less accurate file search fallback |
| clipboard tool (`xclip`/`xsel`/`wl-clipboard` on Linux, `pbcopy`/`pbpaste` built-in on macOS, `win32yank` on Windows) | `unnamedplus` system clipboard sync | Yank/paste no longer shares with the OS clipboard |

### LSP servers & formatters (NOT installed via Mason)

This config deliberately does **not** use Mason — see the comment at the top
of `init.lua`. On the machine this was written on, these binaries come from
a NixOS system config (`/etc/nixos/cfg/neovim.nix`), which is **not** part of
this repo:

- `lua_ls`, `nixd`, `pyright`, `clangd`, `html` (via `nvim-lspconfig`)
- `stylua`, `nixfmt`, `ruff_format`, `clang_format` (via `conform.nvim`, on-demand with `<leader>f`)

On any device without that Nix config (including non-NixOS machines), these
need to be installed some other way (system package manager, Mason, etc.) or
LSP features (`gd`, `gr`, `K`, `<leader>rn`, `<leader>ca`, diagnostics) and
formatting will not work, even though the plugins themselves load fine.

### Plugin version pinning

There is no `lazy-lock.json` in this repo yet — it's generated the first
time lazy.nvim installs plugins, at `~/.config/nvim/lazy-lock.json`. Once you
have one, commit it here too; otherwise each device that does a fresh
install pulls whatever the latest plugin commits are at install time, so
devices can silently drift apart in plugin versions.
