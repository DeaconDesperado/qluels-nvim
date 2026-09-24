local project = require("qluels.project")

describe("qluels.project", function()
  it("prefers the nearest qlue-ls config over the git root", function()
    local root = vim.fn.tempname()
    local nested = root .. "/queries"
    vim.fn.mkdir(root .. "/.git", "p")
    vim.fn.mkdir(nested, "p")
    vim.fn.writefile({ "backends: {}" }, nested .. "/qlue-ls.yaml")

    local previous = vim.api.nvim_get_current_buf()
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(bufnr, nested .. "/query.sparql")
    vim.api.nvim_set_current_buf(bufnr)
    assert.equals(vim.uv.fs_realpath(nested), project.root(bufnr))

    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.fn.delete(root, "rf")
  end)
end)
