--- Lock file: tracks installed parsers and last update time.
--- All writes go through vim.schedule to serialize against concurrent installs.

--- @class arborist.LockEntry
--- @field mode string Install mode: "wasm-cdn", "wasm-built", or "native"
--- @field installed_at string ISO date (YYYY-MM-DD)

--- @class arborist.Lock
--- @field parsers table<string, arborist.LockEntry>
--- @field last_update string ISO date or ""

local M = {}

--- @type string
local path

--- Set the lock file path. Called once during setup.
--- @param p string
function M.init(p) path = p end

--- Read and parse the lock file. Returns empty lock on any failure.
--- @return arborist.Lock
function M.read()
  local f = io.open(path, "r")
  if not f then return { parsers = {}, last_update = "" } end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  if ok and type(data) == "table" and type(data.parsers) == "table" then
    return data
  end
  return { parsers = {}, last_update = "" }
end

--- Write lock data to disk. Silently fails on IO errors.
--- @param lock arborist.Lock
function M.write(lock)
  local f = io.open(path, "w")
  if not f then return end
  f:write(vim.json.encode(lock))
  f:close()
end

--- Record a successful install. Serialized via vim.schedule.
--- @param lang string
--- @param mode string
function M.record(lang, mode)
  vim.schedule(function()
    local lock = M.read()
    lock.parsers[lang] = { mode = mode, installed_at = os.date("%Y-%m-%d") }
    M.write(lock)
  end)
end

--- Mark today as the last update check. Serialized via vim.schedule.
function M.touch_update()
  vim.schedule(function()
    local lock = M.read()
    lock.last_update = os.date("%Y-%m-%d")
    M.write(lock)
  end)
end

return M
