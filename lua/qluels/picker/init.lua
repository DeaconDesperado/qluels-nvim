---Picker module for selecting backends
---Automatically detects available pickers (telescope, fzf-lua, snacks) and falls back to vim.ui.select
local M = {}

---@enum PickerName
M.PickerName = {
  telescope = "telescope.nvim",
  fzf_lua = "fzf-lua",
  snacks = "snacks.nvim",
}

---Get a picker instance via auto-detection
---@return table picker Picker adapter with pick() method
M.get = function()
  -- Auto-detect: try pickers in order
  for _, picker_name in ipairs({ M.PickerName.telescope, M.PickerName.fzf_lua, M.PickerName.snacks }) do
    local module_name = M._picker_module_name(picker_name)
    local ok, picker = pcall(require, "qluels.picker." .. module_name)
    if ok and picker.available() then
      return picker
    end
  end

  -- Fallback to default (vim.ui.select)
  return require("qluels.picker._default")
end

---Convert picker name to module name
---@param name string Picker name
---@return string module_name Module name without "qluels.picker." prefix
M._picker_module_name = function(name)
  local map = {
    [M.PickerName.telescope] = "_telescope",
    [M.PickerName.fzf_lua] = "_fzf",
    [M.PickerName.snacks] = "_snacks",
  }
  return map[name] or "_default"
end

---Pick a backend from the list
---@param callback fun(backend?: string) Called with selected backend name or nil if cancelled
---@param bufnr? number Buffer number for LSP client
M.pick_backend = function(callback, bufnr)
  local lsp = require("qluels.lsp")

  lsp.list_backends(function(backends, err)
    if err then
      vim.notify("Failed to list backends: " .. err, vim.log.levels.ERROR)
      callback(nil)
      return
    end

    if not backends or #backends == 0 then
      vim.notify("No backends available", vim.log.levels.WARN)
      callback(nil)
      return
    end

    local picker = M.get()
    picker.pick(backends, {
      prompt = "Select Backend",
      on_select = callback,
    })
  end, bufnr)
end

return M
