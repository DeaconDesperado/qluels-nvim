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

  describe("execute_query", function()
    it("returns false when qlue-ls is not attached", function()
      local success = lsp.execute_operation(function() end)
      assert.is_false(success)
    end)
  end)
end)

-- Note: More comprehensive tests would require mocking the LSP client,
-- which is beyond the scope of this initial test setup.
-- For integration tests, you would want to:
-- 1. Start a real qlue-ls server
-- 2. Attach the LSP client to a buffer
-- 3. Test the actual LSP communication
