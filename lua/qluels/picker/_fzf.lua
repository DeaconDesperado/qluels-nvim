---fzf-lua picker adapter
---Provides backend selection using fzf-lua
local M = {}

---Check if fzf-lua is available
---@return boolean
M.available = function()
  local ok = pcall(require, "fzf-lua")
  return ok
end

---Pick from a list of items using fzf-lua
---@param items ListBackendsResponse[] Backends to pick from
---@param opts table Options with prompt and on_select callback
M.pick = function(items, opts)
  opts = opts or {}
  local fzf = require("fzf-lua")
  local names = {}
  for _, value in pairs(items) do
    local marker = value.default and " *" or ""
    table.insert(names, value.name .. marker)
  end

  fzf.fzf_exec(names, {
    prompt = (opts.prompt or "Select") .. "> ",
    actions = {
      ["default"] = function(selected)
        if opts.on_select and selected and #selected > 0 then
          -- Strip the default marker before passing back
          local name = selected[1]:gsub(" %*$", "")
          opts.on_select(name)
        end
      end,
    },
  })
end

return M
