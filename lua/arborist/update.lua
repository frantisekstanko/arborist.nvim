--- Update logic: cadence check and per-parser git diff.

local lock = require("arborist.lock")
local log = require("arborist.log")
local queries = require("arborist.queries")
local registry = require("arborist.registry")

local M = {}

--- Check if a cached repo has new upstream commits.
--- @param repo_dir string
--- @param callback fun(changed: boolean)
local function check_changed(repo_dir, callback)
  local stat = vim.uv.fs_stat(repo_dir)
  if not stat or stat.type ~= "directory" then
    callback(true) -- not cached, needs install
    return
  end
  vim.system({ "git", "-C", repo_dir, "rev-parse", "HEAD" }, { text = true }, function(old)
    local old_rev = (old.stdout or ""):gsub("%s+", "")
    vim.system({ "git", "-C", repo_dir, "fetch", "--depth", "1", "--quiet" }, {}, function(fetch)
      if fetch.code ~= 0 then
        callback(false) -- fetch failed, skip this parser
        return
      end
      vim.system({ "git", "-C", repo_dir, "rev-parse", "FETCH_HEAD" }, { text = true }, function(new)
        local new_rev = (new.stdout or ""):gsub("%s+", "")
        if old_rev ~= new_rev then
          vim.system({ "git", "-C", repo_dir, "reset", "--hard", "FETCH_HEAD" }, {}, function()
            callback(true)
          end)
        else
          callback(false)
        end
      end)
    end)
  end)
end

--- Find the cached clone directory for a parser.
--- @param info arborist.ParserInfo
--- @param repo_cache string
--- @return string
local function find_repo_dir(info, repo_cache)
  local name = info.url:match("([^/]+)$")
  local dir = repo_cache .. "/" .. name
  local stat = vim.uv.fs_stat(dir)
  if stat and stat.type == "directory" then return dir end
  if info.fallback_url then
    return repo_cache .. "/" .. info.fallback_url:match("([^/]+)$")
  end
  return dir
end

--- Update all installed parsers. Only reinstalls those with new upstream commits.
--- @param install_fn fun(lang: string, callback?: fun(err: string?)) Install function
--- @param repo_cache string Path to cached repo clones
function M.update_all(install_fn, repo_cache)
  local data = lock.read()
  local langs = vim.tbl_keys(data.parsers)
  if #langs == 0 then
    log.info("No parsers installed")
    return
  end

  log.info("Checking " .. #langs .. " parsers for updates...")

  -- Refresh enhanced queries alongside parser updates
  queries.fetch()

  local total = #langs
  local checked = 0
  local updated = 0

  local function maybe_finish()
    if checked < total then return end
    lock.touch_update()
    if updated > 0 then
      log.info("Updated " .. updated .. " of " .. total .. " parsers")
    else
      log.info("All parsers up to date")
    end
  end

  for _, lang in ipairs(langs) do
    local info = registry.resolve(lang)
    local dir = find_repo_dir(info, repo_cache)
    check_changed(dir, function(changed)
      if changed then
        install_fn(lang, function(err)
          checked = checked + 1
          if not err then updated = updated + 1 end
          maybe_finish()
        end)
      else
        checked = checked + 1
        maybe_finish()
      end
    end)
  end
end

--- Check if an update is due based on the configured cadence.
--- @param cadence "daily"|"weekly"|"manual"
--- @return boolean
function M.due(cadence)
  if cadence == "manual" then return false end
  local data = lock.read()
  if data.last_update == "" then return false end
  local y, m, d = data.last_update:match("(%d+)-(%d+)-(%d+)")
  if not y then return false end
  local last = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })
  local days = os.difftime(os.time(), last) / 86400
  return days >= (cadence == "daily" and 1 or 7)
end

return M
