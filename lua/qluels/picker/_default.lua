---Default picker implementation using vim.ui.select
---Always available as a fallback when no other picker is installed
local M = {}

---Check if this picker is available
---@return boolean
M.available = function()
  return true -- Always available
end

---Pick from a list of items
---@param items string[] Items to pick from
---@param opts table Options with prompt and on_select callback
M.pick = function(items, opts)
  opts = opts or {}

  vim.ui.select(items, {
    prompt = opts.prompt or "Select item",
    format_item = function(item)
      return item
    end,
  }, function(selected)
    if opts.on_select then
      opts.on_select(selected)
    end
  end)
end

return M
