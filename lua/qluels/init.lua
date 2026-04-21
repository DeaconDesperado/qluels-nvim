---Qluels: Neovim plugin for qlue-ls SPARQL language server
---
---Provides enhanced integration with qlue-ls, including:
--- - Custom LSP actions (addBackend, updateBackend, etc.)
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

  if opts.auto_attach then
    -- Create autocommand for filetype-specific LSP activation
    vim.api.nvim_create_autocmd("FileType", {
      pattern = opts.server.filetypes or {"sparql"},
      group = vim.api.nvim_create_augroup("QluelsLspAttach", { clear = true }),
      callback = function(args)
        local default_capabilities = vim.lsp.protocol.make_client_capabilities()

        vim.lsp.start({
          name = constants.QLUE_IDENTITY,
          cmd = { 'qlue-ls', 'server' },
          capabilities = vim.tbl_deep_extend(
            "force",
            default_capabilities,
            opts.server.capabilities or {}
          ),
          root_dir = vim.fs.root(args.buf, {".git"}) or vim.fn.getcwd(),
          on_attach = opts.server.on_attach,
        }, { bufnr = args.buf })
      end,
    })
  end

  -- Store a flag that we've been set up
  vim.g.qluels_setup_complete = true

  -- Set up SPARQL semantic token highlight groups
  if config.current.semantic_highlighting then
    local semantic_links = {
      ["@lsp.type.keyword.sparql"]   = "Keyword",
      ["@lsp.type.function.sparql"]  = "Function",
      ["@lsp.type.variable.sparql"]  = "Identifier",
      ["@lsp.type.string.sparql"]    = "String",
      ["@lsp.type.number.sparql"]    = "Number",
      ["@lsp.type.comment.sparql"]   = "Comment",
      ["@lsp.type.operator.sparql"]  = "Operator",
      ["@lsp.type.namespace.sparql"] = "Include",
    }
    for group, link in pairs(semantic_links) do
      vim.api.nvim_set_hl(0, group, { link = link })
    end
  else
    local token_types = { "keyword", "function", "variable", "string", "number", "comment", "operator", "namespace" }
    for _, tt in ipairs(token_types) do
      vim.api.nvim_set_hl(0, "@lsp.type." .. tt .. ".sparql", {})
    end
  end

  -- Auto-register configured backends and push settings when LSP attaches
  local has_backends = next(config.current.backends)
  local has_settings = config.current.settings ~= nil

  if has_backends or has_settings then
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("QluelsBackendSetup", { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == constants.QLUE_IDENTITY then
          -- Register all configured backends
          if has_backends then
            for name, backend in pairs(config.current.backends) do
              lsp.add_backend(backend, args.buf)
              vim.notify("Registered backend: " .. name, vim.log.levels.INFO)
            end
          end

          -- Push settings to server
          if has_settings then
            lsp.change_settings(config.current.settings, args.buf)
          end

          -- Set up on-type formatting if enabled
          if config.current.on_type_formatting then
            local otf_group = vim.api.nvim_create_augroup("QluelsOnTypeFormatting_" .. args.buf, { clear = true })
            vim.api.nvim_create_autocmd("InsertCharPre", {
              group = otf_group,
              buffer = args.buf,
              callback = function()
                local char = vim.v.char
                if char == ";" or char == "." then
                  vim.defer_fn(function()
                    if vim.api.nvim_buf_is_valid(args.buf) then
                      client:request("textDocument/onTypeFormatting", {
                        textDocument = { uri = vim.uri_from_bufnr(args.buf) },
                        position = {
                          line = vim.fn.line(".") - 1,
                          character = vim.fn.col("."),
                        },
                        ch = char,
                        options = {
                          tabSize = vim.bo[args.buf].tabstop,
                          insertSpaces = vim.bo[args.buf].expandtab,
                        },
                      }, function(err, result)
                        if result then
                          vim.lsp.util.apply_text_edits(result, args.buf, client.offset_encoding)
                        end
                      end, args.buf)
                    end
                  end, 0)
                end
              end,
            })
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
