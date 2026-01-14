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
---@param items string[] Items to pick from
---@param opts table Options with prompt and on_select callback
M.pick = function(items, opts)
  opts = opts or {}
  local fzf = require("fzf-lua")

  fzf.fzf_exec(items, {
    prompt = (opts.prompt or "Select") .. "> ",
    actions = {
      ["default"] = function(selected)
        if opts.on_select and selected and #selected > 0 then
          opts.on_select(selected[1])
        end
      end,
    },
  })
end

return M
