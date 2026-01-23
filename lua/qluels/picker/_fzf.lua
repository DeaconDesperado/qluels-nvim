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
  local names = {}
  for key, value in pairs(items) do
    -- Convert key and value to string as needed
    table.insert(names, value.name)
  end


  vim.notify(vim.inspect(results))

  fzf.fzf_exec(names, {
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
