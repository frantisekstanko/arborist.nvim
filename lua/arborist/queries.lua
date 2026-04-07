--- Enhanced queries: clone, cache, and overlay community-curated .scm files.
--- The queries repo (arborist-ts/queries) provides richer highlights, folds,
--- injections, and indents than most parser repos ship by default.

local config = require("arborist.config")
local log = require("arborist.log")

local M = {}

local repo_dir --- @type string
local fetching = false
local fetch_queue = {} --- @type fun()[]

--- @param cache_dir string
function M.init(cache_dir)
  repo_dir = cache_dir .. "/queries-repo"
end

--- Clone or update the queries repo. Async via vim.system.
--- Concurrent callers are queued behind one operation.
--- @param callback? fun()
function M.fetch(callback)
  if callback then fetch_queue[#fetch_queue + 1] = callback end
  if fetching then return end
  fetching = true

  local function finish()
    fetching = false
    local cbs = fetch_queue
    fetch_queue = {}
    for _, cb in ipairs(cbs) do cb() end
  end

  local stat = vim.uv.fs_stat(repo_dir)
  if stat and stat.type == "directory" then
    -- Update existing clone
    vim.system(
      { "git", "-C", repo_dir, "fetch", "--depth", "1", "--quiet", "origin", "main" },
      {},
      function(r)
        if r.code ~= 0 then finish(); return end
        vim.system(
          { "git", "-C", repo_dir, "reset", "--hard", "--quiet", "origin/main" },
          {},
          function() finish() end
        )
      end
    )
  else
    -- Fresh shallow clone
    vim.system(
      { "git", "clone", "--depth", "1", "--single-branch", "--quiet",
        config.values.queries_url, repo_dir },
      {},
      function(r)
        if r.code ~= 0 then log.warn("Failed to clone queries repo") end
        finish()
      end
    )
  end
end

--- Check if the cached queries repo is missing or stale (>1 day).
--- @return boolean
function M.needs_refresh()
  local stat = vim.uv.fs_stat(repo_dir .. "/.git/FETCH_HEAD")
  if not stat then
    -- No FETCH_HEAD — check if repo exists at all
    local dir_stat = vim.uv.fs_stat(repo_dir)
    return not dir_stat or dir_stat.type ~= "directory"
  end
  return os.difftime(os.time(), stat.mtime.sec) / 86400 > 1
end

--- Copy enhanced queries for a single language to the install destination.
--- Overlays on top of existing files (parser-repo queries preserved if not overridden).
--- Must be called from the main thread (uses vim.fn).
--- @param lang string
--- @param query_dir string Destination base dir (e.g. site/queries)
function M.copy(lang, query_dir)
  local src = repo_dir .. "/" .. lang
  if vim.fn.isdirectory(src) == 0 then return end

  local dest = query_dir .. "/" .. lang
  vim.fn.mkdir(dest, "p")

  for _, path in ipairs(vim.fn.glob(src .. "/*.scm", false, true)) do
    local name = vim.fn.fnamemodify(path, ":t")
    local inp = io.open(path, "r")
    if inp then
      local data = inp:read("*a")
      inp:close()
      local out = io.open(dest .. "/" .. name, "w")
      if out then out:write(data); out:close() end
    end
  end
end

return M
