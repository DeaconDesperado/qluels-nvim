---Tests for qluels.lsp module
local lsp = require("qluels.lsp")

describe("qluels.lsp", function()
  local original_get_client

  before_each(function()
    original_get_client = lsp.get_client
  end)

  after_each(function()
    lsp.get_client = original_get_client
  end)

  describe("get_client", function()
    it("returns nil when no qlue-ls client is attached", function()
      -- In a test environment, there's typically no LSP client
      local client = lsp.get_client()
      assert.is_nil(client)
    end)
  end)

  describe("format_error", function()
    it("includes structured qlue-ls operation details", function()
      local message = lsp.format_error({
        message = "The endpoint returned an http error.",
        data = { type = "Http", statusCode = 404, statusText = "Not Found", body = "missing" },
      })
      assert.matches("Http", message)
      assert.matches("HTTP 404 Not Found", message)
      assert.matches("missing", message)
    end)
  end)

  describe("is_attached", function()
    it("returns false when no qlue-ls client is attached", function()
      local attached = lsp.is_attached()
      assert.is_false(attached)
    end)
  end)

  describe("add_backend", function()
    it("returns false when qlue-ls is not attached", function()
      local params = {
        name = "test",
        url = "http://localhost/sparql",
      }

      local success = lsp.add_backend(params)
      assert.is_false(success)
    end)

    it("uses the qlue-ls 3.11 request contract", function()
      local captured
      lsp.get_client = function()
        return {
          request = function(_, method, params, callback, bufnr)
            captured = { method = method, params = params, bufnr = bufnr }
            callback(nil, nil)
          end,
        }
      end
      local callback_success
      assert.is_true(lsp.add_backend({ name = "test", url = "http://example.test" }, 7, function(success)
        callback_success = success
      end))
      assert.equals("qlueLs/addBackend", captured.method)
      assert.equals("test", captured.params.name)
      assert.equals(7, captured.bufnr)
      assert.is_true(callback_success)
    end)
  end)

  describe("update_default_backend", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.update_default_backend("test")
      assert.is_false(success)
    end)
  end)

  describe("ping_backend", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.ping_backend("test", function() end)
      assert.is_false(success)
    end)

    it("decodes the object response", function()
      lsp.get_client = function()
        return {
          request = function(_, _, _, callback) callback(nil, { available = true }) end,
        }
      end
      local available
      lsp.ping_backend(nil, function(value) available = value end)
      assert.is_true(available)
    end)
  end)

  describe("execute_operation", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.execute_operation(function() end)
      assert.is_false(success)
    end)

    it("executes inline query text with current option names", function()
      local captured
      lsp.get_client = function()
        return {
          request = function(_, method, params, callback)
            captured = { method = method, params = params }
            callback(nil, { queryResult = {} })
          end,
        }
      end
      lsp.execute_query("ASK {}", function() end, { access_token = "secret", result_offset = 2 })
      assert.equals("qlueLs/executeOperation", captured.method)
      assert.equals("ASK {}", captured.params.query)
      assert.equals("secret", captured.params.accessToken)
      assert.equals(2, captured.params.resultOffset)
      assert.is_nil(captured.params.textDocument)
    end)

    it("returns false with optional parameters when not attached", function()
      local success = lsp.execute_operation(
        function() end,
        0, -- bufnr
        100, -- max_result_size
        10, -- result_offset
        "test_token" -- access_token
      )
      assert.is_false(success)
    end)
  end)

  describe("change_settings", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.change_settings({ some = "setting" })
      assert.is_false(success)
    end)

    it("converts documented snake_case settings to camelCase", function()
      local captured
      lsp.get_client = function()
        return { notify = function(_, method, params) captured = { method = method, params = params } end }
      end
      lsp.change_settings({
        format = { align_predicates = false },
        completion = { result_size_limit = 25 },
        auto_line_break = true,
      })
      assert.equals("qlueLs/changeSettings", captured.method)
      assert.is_false(captured.params.format.alignPredicates)
      assert.equals(25, captured.params.completion.resultSizeLimit)
      assert.is_true(captured.params.autoLineBreak)
    end)
  end)

  describe("get_default_settings", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.get_default_settings(function() end)
      assert.is_false(success)
    end)
  end)

  describe("get_backend", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.get_backend(function() end)
      assert.is_false(success)
    end)

    it("uses listBackends to avoid qlue-ls 3.11.1's malformed getBackend response", function()
      lsp.get_client = function()
        return {
          request = function(_, method, _, callback)
            assert.equals("qlueLs/listBackends", method)
            callback(nil, {
              { name = "one", default = false },
              { name = "two", default = true },
            })
          end,
        }
      end
      local selected
      lsp.get_backend(function(value) selected = value end)
      assert.equals("two", selected.name)
    end)
  end)

  describe("cancel_query", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.cancel_query("test-query-id")
      assert.is_false(success)
    end)
  end)

  describe("jump", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.jump(function() end)
      assert.is_false(success)
    end)

    it("returns false with previous=true when not attached", function()
      local success = lsp.jump(function() end, true)
      assert.is_false(success)
    end)

    it("uses the client encoding and sends formatting options", function()
      local previous = vim.api.nvim_get_current_buf()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "é?x" })
      vim.api.nvim_win_set_cursor(0, { 1, 2 })
      local captured
      lsp.get_client = function()
        return {
          offset_encoding = "utf-16",
          request = function(_, method, params, callback)
            captured = { method = method, params = params }
            callback(nil, { edits = {}, position = nil })
          end,
        }
      end
      lsp.jump(function() end, true, bufnr)
      assert.equals("qlueLs/jump", captured.method)
      assert.equals(1, captured.params.position.character)
      assert.is_true(captured.params.previous)
      assert.is_not_nil(captured.params.options.tabSize)
      vim.api.nvim_set_current_buf(previous)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("identify_operation_type", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.identify_operation_type(function() end)
      assert.is_false(success)
    end)
  end)

  describe("parse_tree", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.parse_tree(function() end)
      assert.is_false(success)
    end)

    it("returns false with skip_trivia when not attached", function()
      local success = lsp.parse_tree(function() end, true)
      assert.is_false(success)
    end)
  end)
end)
