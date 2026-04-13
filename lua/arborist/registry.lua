--- Parser registry: load bundled data, resolve parser URLs, register filetypes.
--- Registry data is bundled with the plugin in the registry/ directory.
--- Sourced from the arborist-ts/registry repo via scripts/sync-upstream.sh.
---
--- Files:
---   parsers.toml    — parser name → { url, location? }
---   filetypes.toml  — parser name → [filetype aliases]  (Neovim-specific)
---   ignore.toml     — filetypes to skip                  (Neovim-specific)
---
--- TOML parsing is minimal and purpose-built for these exact formats.
--- It does NOT handle the full TOML spec (no nested tables, no multi-line values).

local config = require("arborist.config")

--- @class arborist.ParserInfo
--- @field url string Git repository URL
--- @field location? string Subdirectory within repo (for mono-repos)
--- @field revision? string Commit SHA or tag to check out (defaults to repo default branch HEAD)
--- @field fallback_url? string Secondary URL to try (set by heuristic resolve only)

local M = {}

--- @type table<string, arborist.ParserInfo>?
local entries = nil

local registry_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h") .. "/registry"
local filetypes_registered = false

-- Minimal TOML readers for our exact registry format.

--- Parse parsers.toml: [section] with url = "..." and optional location = "..."
--- @param path string
--- @return table<string, arborist.ParserInfo>?
local function read_parsers(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local result = {}
  local current --- @type string?
  for line in f:lines() do
    local section = line:match("^%[([%w_]+)%]$")
    if section then
      current = section
      result[current] = {}
    elseif current then
      local key, val = line:match('^(%w+)%s*=%s*"([^"]+)"$')
      if key and val then result[current][key] = val end
    end
  end
  f:close()
  -- Drop entries without a url (comments, metadata)
  for lang, info in pairs(result) do
    if not info.url then result[lang] = nil end
  end
  return next(result) and result or nil
end

--- Parse filetypes.toml: key = ["val1", "val2"] under [filetypes] section.
--- @param path string
--- @return table<string, string[]>
local function read_filetypes(path)
  local f = io.open(path, "r")
  if not f then return {} end
  local result = {}
  for line in f:lines() do
    local lang, arr = line:match("^([%w_]+)%s*=%s*%[(.+)%]$")
    if lang and arr then
      local fts = {}
      for ft in arr:gmatch('"([^"]+)"') do fts[#fts + 1] = ft end
      if #fts > 0 then result[lang] = fts end
    end
  end
  f:close()
  return result
end

--- Parse ignore.toml: list of quoted strings inside [ignore] section.
--- @param path string
--- @return string[]
local function read_ignore(path)
  local f = io.open(path, "r")
  if not f then return {} end
  local result = {}
  for line in f:lines() do
    local ft = line:match('^%s*"([^"]+)"')
    if ft then result[#result + 1] = ft end
  end
  f:close()
  return result
end

--- Register filetype → parser mappings with Neovim. Idempotent.
function M.register_filetypes()
  if filetypes_registered then return end
  local ft_map = read_filetypes(registry_dir .. "/filetypes.toml")
  if not next(ft_map) then return end
  filetypes_registered = true
  for lang, fts in pairs(ft_map) do
    vim.treesitter.language.register(lang, fts)
  end
end

--- Load default ignore list from bundled ignore.toml.
--- @return string[]
function M.load_ignore()
  return read_ignore(registry_dir .. "/ignore.toml")
end

--- Load bundled parser registry. Registers filetypes if found.
--- @return boolean loaded
function M.load()
  if entries then return true end
  entries = read_parsers(registry_dir .. "/parsers.toml")
  if entries then
    M.register_filetypes()
    return true
  end
  return false
end

--- Resolve a language to parser info.
--- Priority: user overrides → bundled registry → heuristic.
--- @param lang string
--- @return arborist.ParserInfo
function M.resolve(lang)
  local overrides = config.values.overrides
  if overrides[lang] then return overrides[lang] end

  M.load()
  if entries and entries[lang] then return entries[lang] end

  -- Heuristic: try standard orgs with underscore→hyphen conversion
  local hyphenated = lang:gsub("_", "-")
  return {
    url = "https://github.com/tree-sitter-grammars/tree-sitter-" .. hyphenated,
    fallback_url = "https://github.com/tree-sitter/tree-sitter-" .. hyphenated,
  }
end

return M
