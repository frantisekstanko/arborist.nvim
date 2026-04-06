--- Schedule-safe notifications. All output goes through vim.notify on the main thread.
local M = {}

--- @param msg string
function M.info(msg)
  vim.schedule(function() vim.notify("[arborist] " .. msg, vim.log.levels.INFO) end)
end

--- @param msg string
function M.warn(msg)
  vim.schedule(function() vim.notify("[arborist] " .. msg, vim.log.levels.WARN) end)
end

--- @param msg string
function M.error(msg)
  vim.schedule(function() vim.notify("[arborist] " .. msg, vim.log.levels.ERROR) end)
end

return M
