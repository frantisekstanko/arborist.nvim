--- sync-upstream-revisions.lua
---
--- Merge nvim-treesitter's lockfile.json into arborist's
--- registry/parsers.toml, adding/updating `revision = "<sha>"` for every
--- language they share. Languages present only in arborist stay as-is;
--- languages only in the lockfile are reported for follow-up.
---
--- Run:
---   cd arborist.nvim
---   nvim --headless --clean \
---     -c "luafile scripts/sync-upstream-revisions.lua" -c "qa!"
---
--- Input path (override via ARBORIST_LOCKFILE env):
---   ~/.local/share/nvim/lazy/nvim-treesitter/lockfile.json
---   https://raw.githubusercontent.com/nvim-treesitter/nvim-treesitter/master/lockfile.json (fallback)
---
--- The script preserves TOML formatting: existing comments, section
--- ordering, blank lines, and URL lines are untouched. A `revision` line
--- is either inserted immediately after the section's `url = "..."` line
--- (for new pins) or updated in place (for existing ones).

local DEFAULT_LOCAL = vim.fn.expand("~/.local/share/nvim/lazy/nvim-treesitter/lockfile.json")
local DEFAULT_REMOTE = "https://raw.githubusercontent.com/nvim-treesitter/nvim-treesitter/master/lockfile.json"

local script_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local plugin_root = vim.fn.fnamemodify(script_dir, ":h")
local parsers_toml = plugin_root .. "/registry/parsers.toml"

local function log(...) io.stdout:write(table.concat({ ... }, " ") .. "\n") end
local function warn(...) io.stderr:write(table.concat({ ... }, " ") .. "\n") end

--- @param path string
--- @return string? content, string? err
local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil, "could not open " .. path end
  local c = f:read("*a")
  f:close()
  return c
end

--- @param path string
--- @param content string
--- @return boolean ok, string? err
local function write_file_atomic(path, content)
  local tmp = path .. ".tmp." .. vim.fn.getpid()
  local f, oerr = io.open(tmp, "wb")
  if not f then return false, oerr end
  f:write(content)
  f:close()
  local ok, rerr = os.rename(tmp, path)
  if not ok then
    pcall(os.remove, tmp)
    return false, rerr
  end
  return true
end

--- Load the lockfile JSON. Try local path first, then fall back to curl.
--- @return table<string, string>? lang->revision
local function load_lockfile()
  local override = os.getenv("ARBORIST_LOCKFILE")
  local paths = override and { override } or { DEFAULT_LOCAL }
  for _, p in ipairs(paths) do
    local c = read_file(p)
    if c then
      local ok, decoded = pcall(vim.json.decode, c)
      if ok and type(decoded) == "table" then
        log("read lockfile:", p)
        local out = {}
        for lang, entry in pairs(decoded) do
          if type(entry) == "table" and type(entry.revision) == "string" then
            out[lang] = entry.revision
          end
        end
        return out
      else
        warn("failed to parse JSON at", p)
      end
    end
  end
  -- Curl fallback
  log("local lockfile not found, fetching", DEFAULT_REMOTE)
  local r = vim.system({ "curl", "-fsSL", DEFAULT_REMOTE }, { text = true }):wait()
  if r.code ~= 0 or not r.stdout or r.stdout == "" then
    warn("curl failed:", (r.stderr or ""):gsub("\n", " "))
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, r.stdout)
  if not ok or type(decoded) ~= "table" then
    warn("failed to parse fetched JSON")
    return nil
  end
  local out = {}
  for lang, entry in pairs(decoded) do
    if type(entry) == "table" and type(entry.revision) == "string" then
      out[lang] = entry.revision
    end
  end
  return out
end

--- Walk the TOML line-by-line. Within each `[section]`, look for the
--- current `revision` line and the `url` line. Emits new/updated lines.
---
--- @param content string current file content
--- @param pins table<string, string>  lang -> sha
--- @return string new_content, { added: integer, updated: integer, unchanged: integer, arborist_only: string[], lockfile_only: table<string, string> }
local function apply(content, pins)
  local lines = {}
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end

  local added, updated, unchanged = 0, 0, 0
  local arborist_langs = {} --- @type table<string, true>

  -- Pass 1: locate sections and their (url_idx, revision_idx) for in-place update.
  local sections = {} --- @type { name: string, start: integer, url_idx: integer?, rev_idx: integer? }[]
  local cur
  for i, line in ipairs(lines) do
    local sec = line:match("^%[([%w_]+)%]%s*$")
    if sec then
      cur = { name = sec, start = i }
      sections[#sections + 1] = cur
      arborist_langs[sec] = true
    elseif cur then
      if line:match("^url%s*=%s*\"") then cur.url_idx = i
      elseif line:match("^revision%s*=%s*\"") then cur.rev_idx = i end
    end
  end

  -- Pass 2: compute edits. Collect (insertion_line_idx -> new_line) for additions
  -- and (existing_idx -> new_line) for updates. Apply in reverse order to keep
  -- indices stable.
  local edits = {} --- @type { idx: integer, new: string, insert: boolean }[]

  for _, sec in ipairs(sections) do
    local pin = pins[sec.name]
    if pin then
      if sec.rev_idx then
        local existing = lines[sec.rev_idx]:match("^revision%s*=%s*\"([^\"]+)\"")
        if existing == pin then
          unchanged = unchanged + 1
        else
          edits[#edits + 1] = { idx = sec.rev_idx, new = 'revision = "' .. pin .. '"', insert = false }
          updated = updated + 1
          log(string.format("update  %s  %s -> %s", sec.name, (existing or "?"):sub(1, 10), pin:sub(1, 10)))
        end
      elseif sec.url_idx then
        edits[#edits + 1] = { idx = sec.url_idx + 1, new = 'revision = "' .. pin .. '"', insert = true }
        added = added + 1
        log(string.format("add     %s  %s", sec.name, pin:sub(1, 10)))
      else
        warn(string.format("skip    %s  (no url= line to anchor against)", sec.name))
      end
    end
  end

  -- Reverse edits so inserts don't shift subsequent indices.
  table.sort(edits, function(a, b) return a.idx > b.idx end)
  for _, e in ipairs(edits) do
    if e.insert then
      table.insert(lines, e.idx, e.new)
    else
      lines[e.idx] = e.new
    end
  end

  -- Report lockfile-only (languages pinned upstream but absent from arborist).
  local lockfile_only = {}
  for lang, rev in pairs(pins) do
    if not arborist_langs[lang] then lockfile_only[lang] = rev end
  end

  -- Report arborist-only (entries with no upstream pin — intentional leftover).
  local arborist_only = {}
  for lang in pairs(arborist_langs) do
    if not pins[lang] then arborist_only[#arborist_only + 1] = lang end
  end
  table.sort(arborist_only)

  return table.concat(lines, "\n") .. "\n", {
    added = added,
    updated = updated,
    unchanged = unchanged,
    arborist_only = arborist_only,
    lockfile_only = lockfile_only,
  }
end

--- Drive.
local function main()
  log("arborist.nvim :: sync-upstream-revisions")
  log("target:", parsers_toml)

  local pins = load_lockfile()
  if not pins then
    warn("no lockfile available")
    os.exit(1)
  end
  local lockfile_count = vim.tbl_count(pins)
  log("lockfile entries:", lockfile_count)

  local content, rerr = read_file(parsers_toml)
  if not content then
    warn("could not read", parsers_toml, "--", rerr)
    os.exit(1)
  end

  local new_content, report = apply(content, pins)

  if new_content ~= content then
    local ok, werr = write_file_atomic(parsers_toml, new_content)
    if not ok then
      warn("write failed:", werr)
      os.exit(1)
    end
    log("wrote:", parsers_toml)
  else
    log("no changes (all pins up to date)")
  end

  log("")
  log(string.format("summary: added=%d updated=%d unchanged=%d arborist_only=%d lockfile_only=%d",
    report.added, report.updated, report.unchanged,
    #report.arborist_only, vim.tbl_count(report.lockfile_only)))

  if #report.arborist_only > 0 then
    log("")
    log("arborist-only (shipped here, no upstream pin available):")
    for _, l in ipairs(report.arborist_only) do log("  " .. l) end
  end
  if next(report.lockfile_only) then
    log("")
    log("lockfile-only (upstream pins these, arborist doesn't ship):")
    local langs = vim.tbl_keys(report.lockfile_only)
    table.sort(langs)
    for _, l in ipairs(langs) do log("  " .. l .. "  " .. report.lockfile_only[l]:sub(1, 10)) end
  end
end

main()
