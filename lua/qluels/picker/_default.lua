---Default picker implementation using vim.ui.select
---Always available as a fallback when no other picker is installed
local M = {}

---Check if this picker is available
---@return boolean
M.available = function()
  return true -- Always available
end

---Pick from a list of items
---@param items ListBackendsResponse[] Items to pick from
---@param opts table Options with prompt and on_select callback
M.pick = function(items, opts)
  opts = opts or {}

  vim.ui.select(items, {
    prompt = opts.prompt or "Select item",
    format_item = function(item)
      local marker = item.default and " *" or ""
      return item.name .. marker
    end,
  }, function(selected)
    if opts.on_select then
      opts.on_select(selected.name)
    end
  end)
end

---Pick from a generic list of items
---@param items table[] Items to pick from
---@param opts table Options: prompt, format_item(item)->string, on_select(item)
M.pick_generic = function(items, opts)
  opts = opts or {}
  vim.ui.select(items, {
    prompt = opts.prompt or "Select item",
    format_item = opts.format_item or tostring,
  }, function(selected)
    if opts.on_select and selected then
      opts.on_select(selected)
    end
  end)
end

return M
