---snacks.nvim picker adapter
---Provides backend selection using snacks.nvim picker
local M = {}

---Check if snacks picker is available
---@return boolean
M.available = function()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks.picker ~= nil
end

---Pick from a list of items using snacks picker
---@param items string[] Items to pick from
---@param opts table Options with prompt and on_select callback
M.pick = function(items, opts)
  opts = opts or {}
  local snacks = require("snacks")

  snacks.picker.pick({
    prompt = opts.prompt or "Select",
    items = items,
    format = function(item)
      return item
    end,
    confirm = function(item)
      if opts.on_select then
        opts.on_select(item)
      end
    end,
  })
end

return M
