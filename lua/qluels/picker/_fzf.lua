---fzf-lua picker adapter
---Provides backend selection using fzf-lua
local fzf = require("fzf-lua")

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

---Pick from a generic list of items using fzf-lua
---@param items table[] Items to pick from
---@param opts table Options: prompt, format_item(item)->string, on_select(item)
M.pick_generic = function(items, opts)
  opts = opts or {}
  local format_item = opts.format_item or tostring

  local display_strings = {}
  local item_map = {}
  for _, item in ipairs(items) do
    local display = format_item(item)
    table.insert(display_strings, display)
    item_map[display] = item
  end

  fzf.fzf_exec(display_strings, {
    prompt = (opts.prompt or "Select") .. "> ",
    actions = {
      ["default"] = function(selected)
        if opts.on_select and selected and #selected > 0 then
          local item = item_map[selected[1]]
          if item then
            opts.on_select(item)
          end
        end
      end,
    },
  })
end

return M
