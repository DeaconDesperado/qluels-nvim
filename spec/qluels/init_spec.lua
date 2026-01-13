---Tests for qluels.init module
local init = require("qluels")
local config = require("qluels.config")

describe("qluels.init", function()
  before_each(function()
    -- Reset configuration
    config.current = vim.deepcopy(config.defaults)
    -- Clear any existing autocommands (only if group exists)
    pcall(function()
      vim.api.nvim_clear_autocmds({ group = "QluelsLspAttach" })
    end)
    pcall(function()
      vim.api.nvim_clear_autocmds({ group = "QluelsBackendSetup" })
    end)
  end)

  describe("setup", function()
    it("successfully sets up with default config", function()
      init.setup()

      -- Should set the global flag
      assert.is_true(vim.g.qluels_setup_complete)
    end)

    it("successfully sets up with custom config", function()
      init.setup({
        backends = {
          wikidata = {
            service = {
              name = "wikidata",
              url = "https://query.wikidata.org/sparql",
            },
            default = true,
          },
        },
        auto_attach = true,
        server = {
          filetypes = { "sparql", "rq" },
        },
      })

      assert.is_true(vim.g.qluels_setup_complete)
      assert.is_not_nil(config.current.backends.wikidata)
    end)

    it("validates config before setup", function()
      -- Capture vim.notify calls
      local notify_called = false
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        if level == vim.log.levels.ERROR then
          notify_called = true
        end
      end

      init.setup({
        auto_attach = "invalid", -- should be boolean
      })

      vim.notify = original_notify
      assert.is_true(notify_called)
    end)

    it("creates FileType autocommand when auto_attach is true", function()
      init.setup({
        auto_attach = true,
        server = {
          filetypes = { "sparql" },
        },
      })

      -- Check that autocommand group exists
      local autocmds = vim.api.nvim_get_autocmds({
        group = "QluelsLspAttach",
      })

      assert.is_true(#autocmds > 0)
      assert.equals("FileType", autocmds[1].event)
    end)

    it("does not create FileType autocommand when auto_attach is false", function()
      init.setup({
        auto_attach = false,
      })

      -- Check that autocommand group doesn't exist or is empty
      local autocmds = vim.api.nvim_get_autocmds({
        group = "QluelsLspAttach",
      })

      assert.equals(0, #autocmds)
    end)

    it("creates backend registration autocommand when backends are configured", function()
      init.setup({
        backends = {
          test = {
            service = {
              name = "test",
              url = "http://localhost/sparql",
            },
          },
        },
      })

      -- Check that LspAttach autocommand exists
      local autocmds = vim.api.nvim_get_autocmds({
        group = "QluelsBackendSetup",
      })

      assert.is_true(#autocmds > 0)
      assert.equals("LspAttach", autocmds[1].event)
    end)

    it("respects custom filetypes", function()
      init.setup({
        auto_attach = true,
        server = {
          filetypes = { "sparql", "rq", "ttl" },
        },
      })

      local autocmds = vim.api.nvim_get_autocmds({
        group = "QluelsLspAttach",
      })

      assert.is_true(#autocmds > 0)
      -- Pattern should include custom filetypes
      -- Note: autocmd pattern is stored as a table
      assert.is_not_nil(autocmds[1].pattern)
    end)
  end)

  describe("reload", function()
    it("clears module cache and reloads", function()
      -- Setup first
      init.setup()

      -- Ensure module is loaded
      assert.is_not_nil(package.loaded["qluels"])
      assert.is_not_nil(package.loaded["qluels.config"])

      -- Reload
      init.reload()

      -- Module should still be loaded (it re-requires)
      assert.is_not_nil(package.loaded["qluels"])
    end)
  end)

  describe("submodule exports", function()
    it("exports config submodule", function()
      assert.is_not_nil(init.config)
      assert.equals(config, init.config)
    end)

    it("exports lsp submodule", function()
      assert.is_not_nil(init.lsp)
    end)

    it("exports query submodule", function()
      assert.is_not_nil(init.query)
    end)
  end)
end)
