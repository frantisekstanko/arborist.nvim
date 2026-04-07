# arborist.nvim

WASM-first tree-sitter parser manager for Neovim 0.12+. Parsers install
automatically when you open files. No manual steps, no maintenance.

## Install

```lua
vim.pack.add({
  "https://github.com/arborist-ts/arborist.nvim",
})
```

Works out of the box with no setup call. To customize:

```lua
vim.pack.add({
  "https://github.com/arborist-ts/arborist.nvim",
})

vim.g.arborist_loaded = true -- skip auto-setup, we're configuring manually
require("arborist").setup({
  update_cadence = "weekly",
  overrides = {
    my_language = { url = "https://github.com/me/tree-sitter-my-language" },
  },
})
```

All options and their defaults:

| Option | Default | Description |
|--------|---------|-------------|
| `prefer_wasm` | `true` | Try WASM before native compilation |
| `update_cadence` | `"daily"` | `"daily"`, `"weekly"`, or `"manual"` |
| `compiler` | `"cc"` | C compiler for native .so builds |
| `queries_url` | `"https://github.com/arborist-ts/queries.git"` | Git URL for enhanced queries repo |
| `ignore` | `{}` | Extra filetypes to skip (merged with registry defaults) |
| `overrides` | `{}` | Extra parsers not in the registry |

## How It Works

1. You open a file
2. Arborist checks if a parser exists for that filetype
3. If not, it installs one:
   - Download pre-built WASM from CDN (fastest)
   - Clone source and `tree-sitter build --wasm`
   - Clone source and `tree-sitter build` (native .so)
4. Enhanced [query files](https://github.com/arborist-ts/queries) (highlights,
   folds, indents, injections) are overlaid automatically
5. Highlighting and indentation activate immediately

WASM steps are skipped entirely if your Neovim build lacks wasmtime.

Parser locations are resolved from a
[community registry](https://github.com/arborist-ts/registry) covering
326 parsers. Unknown parsers fall back to convention-based lookup in the
`tree-sitter-grammars` and `tree-sitter` GitHub orgs.

Query files from parser repos are supplemented with community-curated
[enhanced queries](https://github.com/arborist-ts/queries) for richer
syntax highlighting, folding, and indentation. User queries in
`~/.config/nvim/queries/` always take highest priority.

## Commands

| Command | Description |
|---------|-------------|
| `:Arborist` | Show installed parsers and status |
| `:ArboristInstall {lang}` | Install a parser manually |
| `:ArboristUpdate` | Check all parsers for updates |
| `:ArboristClean` | Remove all arborist-managed parsers and cache |

## Requirements

- Neovim 0.12+
- `git` and `curl`
- `tree-sitter` CLI (for building from source)
- A C compiler (fallback when `tree-sitter` CLI is unavailable)
- For WASM: Neovim built with `ENABLE_WASMTIME=ON`

## License

[MIT](LICENSE)
