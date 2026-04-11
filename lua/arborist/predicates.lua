--- Register tree-sitter query predicate/directive handlers not built into Neovim.
--- Called once during setup(), before any vim.treesitter.start().

local M = {}

function M.register()
  local query = vim.treesitter.query

  -- #kind-eq? @capture "type1" "type2" ...
  -- True when the captured node's type matches any of the given strings.
  pcall(query.add_predicate, "kind-eq?", function(match, _, _, pred)
    local nodes = match[pred[2]]
    if not nodes then return false end
    for _, node in ipairs(nodes) do
      local kind = node:type()
      for i = 3, #pred do
        if kind == pred[i] then return true end
      end
    end
    return false
  end, { force = false })

  -- #not-kind-eq? @capture "type1" "type2" ...
  -- True when the captured node's type does NOT match any of the given strings.
  pcall(query.add_predicate, "not-kind-eq?", function(match, _, _, pred)
    local nodes = match[pred[2]]
    if not nodes then return true end
    for _, node in ipairs(nodes) do
      local kind = node:type()
      for i = 3, #pred do
        if kind == pred[i] then return false end
      end
    end
    return true
  end, { force = false })

  -- #is? / #is-not? — directives used by tree-sitter-highlight for local-scope
  -- tracking. Neovim handles scoping via locals.scm, so these are no-ops.
  pcall(query.add_directive, "is?", function() end, { force = false })
  pcall(query.add_directive, "is-not?", function() end, { force = false })
end

return M
