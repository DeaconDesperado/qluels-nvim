---Tests for qluels.lsp module
local lsp = require("qluels.lsp")

describe("qluels.lsp", function()
  describe("get_client", function()
    it("returns nil when no qlue-ls client is attached", function()
      -- In a test environment, there's typically no LSP client
      local client = lsp.get_client()
      assert.is_nil(client)
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
        service = {
          name = "test",
          url = "http://localhost/sparql",
        },
      }

      local success = lsp.add_backend(params)
      assert.is_false(success)
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
  end)

  describe("execute_operation", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.execute_operation(function() end)
      assert.is_false(success)
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
  end)

  describe("get_default_settings", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.get_default_settings(function() end)
      assert.is_false(success)
    end)
  end)
end)
