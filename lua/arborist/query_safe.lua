--- Safe wrappers around vim.treesitter.query.get and query:iter_captures.
---
--- Why: a malformed .scm (from a community-inherited query, a parser
--- version drift, or a user-authored override) makes query.get throw.
--- Unhandled, the throw cascades out of arborist's FileType autocmd into
--- whatever triggered that event — including nvim-dap's terminal-buffer
--- setup, breaking unrelated downstream flows (a Python indent crash
--- breaking a Python debugger launch).
---
--- Semantics:
---   * query.get returns nil for transient failures (parser still loading,
---     query file absent). Silent — auto-retries on next buffer event.
---   * query.get throws for permanent failures (malformed .scm). Notify
---     once per (lang, qtype, err_string) per Neovim session.
---   * iter_captures can throw mid-iteration on predicate evaluation errors.
---     Wrap each step; on error, notify once and stop iteration.
---
--- Dedup keys include the error string so a freshly-introduced error after
--- a query edit re-notifies the user (confirmation the edit landed).

local M = {}

-- key = lang .. "\0" .. qtype .. "\0" .. err  ->  true
local notified = {}

local function notify_once(key, msg, level)
  if notified[key] then return end
  notified[key] = true
  vim.schedule(function() vim.notify("[arborist] " .. msg, level or vim.log.levels.ERROR) end)
end

--- Invalidate dedup memory so the user sees confirmation on the next load
--- after they've edited a query. Called with no args to reset everything.
--- @param lang? string
--- @param qtype? string
function M.reset(lang, qtype)
  if not lang then
    notified = {}
    return
  end
  local prefix = lang .. "\0" .. (qtype or "") .. "\0"
  for k in pairs(notified) do
    if k:sub(1, #prefix) == prefix then notified[k] = nil end
  end
end

--- Reset all dedup state (test hook).
function M.reset_all() notified = {} end

--- Returns the compiled query, or nil on any failure.
--- Silent for transient "not loaded" (nil return). Notifies once per
--- distinct error for permanent "malformed" (throw).
--- @param lang string
--- @param qtype string
--- @return vim.treesitter.Query?
function M.safe_get(lang, qtype)
  local ok, q_or_err = pcall(vim.treesitter.query.get, lang, qtype)
  if ok then return q_or_err end
  local err = tostring(q_or_err or "unknown")
  local key = lang .. "\0" .. qtype .. "\0" .. err
  notify_once(
    key,
    string.format("malformed %s/%s.scm: %s", lang, qtype, err:gsub("^.-:%s*", ""))
  )
  return nil
end

--- Iterator adapter for query:iter_captures that swallows runtime throws
--- from predicate evaluation. On error, notifies once and ends iteration
--- cleanly (returns nil, which is Lua's for-in termination).
--- @param query vim.treesitter.Query
--- @param lang string for dedup keying
--- @param qtype string for dedup keying
--- @param node TSNode
--- @param bufnr integer
--- @param start_row? integer
--- @param end_row? integer
function M.safe_iter_captures(query, lang, qtype, node, bufnr, start_row, end_row)
  local ok_it, iter = pcall(query.iter_captures, query, node, bufnr, start_row, end_row)
  if not ok_it then
    notify_once(
      lang .. "\0" .. qtype .. "\0iter:" .. tostring(iter),
      string.format("query %s/%s iter_captures failed: %s", lang, qtype, tostring(iter))
    )
    return function() return nil end
  end
  return function()
    local ok, id, n, meta = pcall(iter)
    if not ok then
      notify_once(
        lang .. "\0" .. qtype .. "\0step:" .. tostring(id),
        string.format("query %s/%s runtime error: %s", lang, qtype, tostring(id))
      )
      return nil
    end
    return id, n, meta
  end
end

return M
