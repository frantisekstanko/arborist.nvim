--- Register tree-sitter query predicate/directive handlers not built into Neovim.
--- Called once during setup(), before any vim.treesitter.start().

local M = {}

function M.register()
  local query = vim.treesitter.query

  -- #kind-eq? @capture "type1" "type2" ...
  -- True when the captured node's type matches any of the given strings.
  local function kind_eq(match, _, _, pred)
    local nodes = match[pred[2]]
    if not nodes then return false end
    for _, node in ipairs(nodes) do
      local kind = node:type()
      for i = 3, #pred do
        if kind == pred[i] then return true end
      end
    end
    return false
  end

  pcall(query.add_predicate, "kind-eq?", kind_eq, { force = false })
  pcall(query.add_predicate, "not-kind-eq?", function(...) return not kind_eq(...) end, { force = false })

  -- #is? / #is-not? — directives used by tree-sitter-highlight for local-scope
  -- tracking. Neovim handles scoping via locals.scm, so these are no-ops.
  local noop = function() end
  pcall(query.add_directive, "is?", noop, { force = false })
  pcall(query.add_directive, "is-not?", noop, { force = false })
end

return M
