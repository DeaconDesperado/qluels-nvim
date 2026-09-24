local M = {}

---Resolve the qlue-ls project root for a buffer.
---@param bufnr? number
---@return string
M.root = function(bufnr)
  bufnr = bufnr or 0
  local config_root = vim.fs.root(bufnr, { "qlue-ls.toml", "qlue-ls.yml", "qlue-ls.yaml" })
  return config_root or vim.fs.root(bufnr, { ".git" }) or vim.fn.getcwd()
end

return M
