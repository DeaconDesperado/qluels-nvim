---Qluels: Neovim plugin for qlue-ls SPARQL language server
---
---Provides enhanced integration with qlue-ls, including:
--- - Custom LSP actions (addBackend, updateDefaultBackend, etc.)
--- - SPARQL query execution with formatted results
--- - Backend management
local M = {}

local constants = require("qluels.constants");
local config = require("qluels.config")
local lsp = require("qluels.lsp")
local query = require("qluels.query")

---Setup the plugin
---@param opts? QluelsConfig User configuration
M.setup = function(opts)
  opts = opts or {}

  -- Setup configuration
  local success, err = config.setup(opts)
  if not success then
    vim.notify("Qluels setup failed: " .. err, vim.log.levels.ERROR)
    return
  end

  local default_capabilities = vim.lsp.protocol.make_client_capabilities();
  local default_on_attach = vim.lsp.handlers.default_on_attach

  if opts.auto_attach then
    vim.lsp.config ("qlue-ls", {
      name = constants.QLUE_IDENTITY,
      filetypes = opts.server.filetypes,
      cmd = { 'qlue-ls', 'server' },
      capabilities = vim.tbl_deep_extend(
        "force",
        default_capabilities,
        opts.server.capabilities or {}
      ),
      root_dir = vim.fn.getcwd(),
      on_attach = opts.on_attach or default_on_attach
    })

    vim.lsp.enable({constants.QLUE_IDENTITY})
  end

  -- Store a flag that we've been set up
  vim.g.qluels_setup_complete = true

  -- Auto-register configured backends when LSP attaches
  if next(config.current.backends) then
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("QluelsBackendSetup", { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == constants.QLUE_IDENTITY then
          -- Register all configured backends
          for name, backend in pairs(config.current.backends) do
            lsp.add_backend(backend, args.buf)
            vim.notify("Registered backend: " .. name, vim.log.levels.INFO)
          end
        end
      end,
    })
  end
end

---Reload the plugin (useful during development)
---Clears the module cache and re-requires the plugin
M.reload = function()
  -- Clear module cache
  for name, _ in pairs(package.loaded) do
    if name:match("^qluels") then
      package.loaded[name] = nil
    end
  end

  -- Re-require
  require("qluels")

  vim.notify("Qluels plugin reloaded", vim.log.levels.INFO)
end

-- Export submodules for direct access if needed
M.config = config
M.lsp = lsp
M.query = query

return M
