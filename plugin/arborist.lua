if vim.g.arborist_loaded then return end
vim.g.arborist_loaded = true

local ok, err = pcall(require("arborist").setup)
if not ok then
  vim.notify("[arborist] setup failed: " .. tostring(err), vim.log.levels.ERROR)
end
