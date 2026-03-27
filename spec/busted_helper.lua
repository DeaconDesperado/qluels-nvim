-- Ensure the local lua/ directory takes precedence over any installed version
-- by prepending it to Neovim's runtimepath
local plugin_dir = vim.fn.fnamemodify(".", ":p")
vim.opt.runtimepath:prepend(plugin_dir)

-- Clear any pre-loaded qluels modules so they get re-resolved from the
-- updated runtimepath
for k in pairs(package.loaded) do
  if k:match("^qluels") then
    package.loaded[k] = nil
  end
end
