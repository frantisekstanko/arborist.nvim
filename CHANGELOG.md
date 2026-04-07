# Changelog

All notable changes to this project will be documented in this file.

## 0.2.0 — 2026-04-07

- Enhanced queries: community-curated highlights, folds, indents, and injections
  from [arborist-ts/queries](https://github.com/arborist-ts/queries), overlaid
  automatically on top of parser-repo queries (329 languages)
- Queries applied to built-in parsers (e.g. lua, vim, markdown) on FileType
- New config option: `queries_url` for custom queries repo
- ArboristClean now wipes all query files (not just lock-file entries)

## 0.1.0 — 2026-04-06

Initial release.

- WASM-first install chain: CDN download → tree-sitter build --wasm → native .so
- Auto-detect and install parsers on FileType events
- Registry-driven parser resolution (326 parsers)
- Neovim filetype mappings and ignore list from registry
- Convention-based fallback for parsers not in the registry
- Daily auto-update with per-parser git diff
- Commands: `:Arborist`, `:ArboristInstall`, `:ArboristUpdate`, `:ArboristClean`
- WASM support detection at startup (instant, no trial-and-error)
- Zero-config via `plugin/arborist.lua`
