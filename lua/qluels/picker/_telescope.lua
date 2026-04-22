---Telescope picker adapter
---Provides backend selection using telescope.nvim
local pickers = require("telescope.pickers")
local entry_display = require("telescope.pickers.entry_display")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

---Check if telescope is available
---@return boolean
M.available = function()
  local ok = pcall(require, "telescope")
  return ok
end

---Pick from a list of items using telescope
---@param items ListBackendsResponse[] Backends to pick from
---@param opts table Options with prompt and on_select callback
M.pick = function(items, opts)
  opts = opts or {}

  local displayer = entry_display.create {
    separator = "|",
    items = {
      { width = 2 },
      { width = 20 },
      { remaining = true },
    },
  }

  local make_display = function(entry)
    local marker = entry.is_default and "*" or " "
    return displayer {
      {marker},
      {entry.name},
      {entry.url}
    }
  end
  --
  -- 3. Iterate and map
  pickers.new({}, {
    prompt_title = opts.prompt or "Select",
    finder = finders.new_table({
      results = items,
      entry_maker = function(entry)
        return {
          value = entry.name,
          ordinal = entry.name,
          name = entry.name,
          url = entry.url,
          is_default = entry.default,
          display = make_display,
        }
      end
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if opts.on_select and selection then
          opts.on_select(selection.name)
        end
      end)
      return true
    end,
  }):find()
end

---Pick from a generic list of items using telescope
---@param items table[] Items to pick from
---@param opts table Options: prompt, format_item(item)->string, on_select(item)
M.pick_generic = function(items, opts)
  opts = opts or {}
  local format_item = opts.format_item or tostring

  pickers.new({}, {
    prompt_title = opts.prompt or "Select",
    finder = finders.new_table({
      results = items,
      entry_maker = function(item)
        local display = format_item(item)
        return {
          value = item,
          ordinal = display,
          display = display,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if opts.on_select and selection then
          opts.on_select(selection.value)
        end
      end)
      return true
    end,
  }):find()
end

return M
