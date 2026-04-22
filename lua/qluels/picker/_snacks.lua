---snacks.nvim picker adapter
---Provides backend selection using snacks.nvim picker
local snacks = require("snacks")

local M = {}

---Check if snacks picker is available
---@return boolean
M.available = function()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks.picker ~= nil
end

---Pick from a list of items using snacks picker
---@param items ListBackendsResponse[] Backends to pick from
---@param opts table Options with prompt and on_select callback
M.pick = function(items, opts)
  opts = opts or {}

  snacks.picker.pick({
    prompt = opts.prompt or "Select",
    items = items,
    format = function(item)
      local marker = item.default and " *" or ""
      return item.name .. marker
    end,
    confirm = function(item)
      if opts.on_select then
        opts.on_select(item.name)
      end
    end,
  })
end

---Pick from a generic list of items using snacks picker
---@param items table[] Items to pick from
---@param opts table Options: prompt, format_item(item)->string, on_select(item)
M.pick_generic = function(items, opts)
  opts = opts or {}
  local format_item = opts.format_item or tostring

  snacks.picker.pick({
    prompt = opts.prompt or "Select",
    items = items,
    format = function(item)
      return format_item(item)
    end,
    confirm = function(item)
      if opts.on_select then
        opts.on_select(item)
      end
    end,
  })
end

return M
