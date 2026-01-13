---Minimal init file for running tests with plenary.nvim
---Usage: nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

-- Add current plugin to runtimepath
local plugin_dir = vim.fn.fnamemodify(vim.fn.expand("<sfile>"), ":h:h")
vim.opt.runtimepath:prepend(plugin_dir)

-- Add plenary to runtimepath (assumes it's installed)
local plenary_dir = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_dir) == 1 then
  vim.opt.runtimepath:prepend(plenary_dir)
else
  -- Try common locations
  local alt_locations = {
    vim.fn.stdpath("data") .. "/site/pack/packer/start/plenary.nvim",
    vim.fn.stdpath("data") .. "/site/pack/*/start/plenary.nvim",
  }

  for _, loc in ipairs(alt_locations) do
    local expanded = vim.fn.glob(loc)
    if expanded ~= "" and vim.fn.isdirectory(expanded) == 1 then
      vim.opt.runtimepath:prepend(expanded)
      break
    end
  end
end

-- Ensure we can require plenary
local has_plenary, plenary = pcall(require, "plenary")
if not has_plenary then
  error("plenary.nvim is required for testing. Please install it first.")
end

-- Setup the plugin with default config
require("qluels").setup({
  backends = {
    test_backend = {
      service = {
        name = "test",
        url = "http://localhost:3030/test/query",
      },
      default = true,
    },
  },
})

print("Minimal init loaded for qluels tests")
