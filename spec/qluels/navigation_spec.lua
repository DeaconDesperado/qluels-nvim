local lsp = require("qluels.lsp")
local navigation = require("qluels.navigation")

describe("qluels.navigation", function()
  local original_get_client

  before_each(function()
    original_get_client = lsp.get_client
  end)

  after_each(function()
    lsp.get_client = original_get_client
  end)

  local function with_non_current_buffer(callback)
    local original_win = vim.api.nvim_get_current_win()
    local original_buf = vim.api.nvim_get_current_buf()
    local bufnr = vim.api.nvim_create_buf(false, true)

    vim.cmd("vsplit")
    local target_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(target_win, bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "é?target" })
    vim.api.nvim_win_set_cursor(target_win, { 1, 3 })
    vim.api.nvim_set_current_win(original_win)

    local ok, err = pcall(callback, bufnr)

    if vim.api.nvim_win_is_valid(target_win) then
      vim.api.nvim_win_close(target_win, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    if vim.api.nvim_buf_is_valid(original_buf) then
      vim.api.nvim_set_current_buf(original_buf)
    end

    assert(ok, err)
  end

  it("builds rename parameters from the requested buffer and its window", function()
    with_non_current_buffer(function(bufnr)
      local captured
      lsp.get_client = function(requested_bufnr)
        assert.equals(bufnr, requested_bufnr)
        return {
          offset_encoding = "utf-16",
          request = function(_, method, params, callback, request_bufnr)
            captured = { method = method, params = params, bufnr = request_bufnr }
            callback(nil, nil)
          end,
        }
      end

      navigation.rename("renamed", bufnr)

      assert.equals("textDocument/rename", captured.method)
      assert.equals(vim.uri_from_bufnr(bufnr), captured.params.textDocument.uri)
      assert.equals(2, captured.params.position.character)
      assert.equals(bufnr, captured.bufnr)
    end)
  end)

  it("builds reference parameters from the requested buffer and its window", function()
    with_non_current_buffer(function(bufnr)
      local captured
      lsp.get_client = function()
        return {
          offset_encoding = "utf-16",
          request = function(_, method, params, callback, request_bufnr)
            captured = { method = method, params = params, bufnr = request_bufnr }
            callback(nil, {})
          end,
        }
      end

      navigation.references(bufnr)

      assert.equals("textDocument/references", captured.method)
      assert.equals(vim.uri_from_bufnr(bufnr), captured.params.textDocument.uri)
      assert.equals(2, captured.params.position.character)
      assert.equals(bufnr, captured.bufnr)
    end)
  end)

  it("keeps folding disabled when its buffer re-enters a window", function()
    local bufnr = vim.api.nvim_get_current_buf()
    navigation.attach(bufnr, { folding = true })
    navigation.disable_folding(bufnr)

    vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = bufnr })

    local win = vim.api.nvim_get_current_win()
    assert.equals("manual", vim.wo[win].foldmethod)
    assert.equals("0", vim.wo[win].foldexpr)
  end)
end)
