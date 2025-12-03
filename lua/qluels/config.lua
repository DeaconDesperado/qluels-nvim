---@class QluelsConfig
---@field server QluelsServer Settings for the language server itself
---@field backends? table<string, QluelsBackend> Pre-configured backends
---@field auto_attach boolean Automatically attach LSP to SPARQL files
---@field result_buffer QluelsResultBufferConfig Result buffer display options

---@class QluelsServer
---@field capabilities? table|nil The client capabilities. 
---@field filetypes? table The filetypes to activate for by default 
---@field on_attach fun(client: vim.lsp.Client, bufnr: number) | nil The function executed when the LSP client attaches to a buffer.

---@class QluelsBackend
---@field service QluelsService Service configuration
---@field requestMethod? "GET"|"POST" HTTP method for queries
---@field default? boolean Set as default backend
---@field prefixMap? table<string, string> Prefix mappings
---@field queries? table<string, string> Completion query templates

---@class QluelsService
---@field name string Backend identifier
---@field url string SPARQL endpoint URL
---@field healthCheckUrl? string Optional health check URL

---@class QluelsResultBufferConfig
---@field position "right"|"left"|"above"|"below" Split position
---@field size number|nil Split size (nil for auto)

local M = {}

---@type QluelsConfig
M.defaults = {
  server = {
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    on_attach = vim.lsp.handlers.default_on_attach,
    filetypes = {"sparql"},
  },
  backends = {},
  auto_attach = true,
  result_buffer = {
    position = "below",
    size = nil, -- Auto-size based on content
  },
}

---Validate a backend configuration
---@param backend_name string
---@param backend QluelsBackend
---@return boolean valid
---@return string? error_message
M.validate_backend = function(backend_name, backend)
  if type(backend_name) ~= "string" or backend_name == "" then
    return false, "Backend name must be a non-empty string"
  end

  if type(backend) ~= "table" then
    return false, "Backend must be a table"
  end

  if type(backend.service) ~= "table" then
    return false, "Backend service must be a table"
  end

  if type(backend.service.name) ~= "string" or backend.service.name == "" then
    return false, "Backend service.name must be a non-empty string"
  end

  if type(backend.service.url) ~= "string" or backend.service.url == "" then
    return false, "Backend service.url must be a non-empty string"
  end

  if backend.requestMethod ~= nil then
    if backend.requestMethod ~= "GET" and backend.requestMethod ~= "POST" then
      return false, "Backend requestMethod must be 'GET' or 'POST'"
    end
  end

  if backend.default ~= nil and type(backend.default) ~= "boolean" then
    return false, "Backend default must be a boolean"
  end

  if backend.prefixMap ~= nil and type(backend.prefixMap) ~= "table" then
    return false, "Backend prefixMap must be a table"
  end

  if backend.queries ~= nil and type(backend.queries) ~= "table" then
    return false, "Backend queries must be a table"
  end

  return true, nil
end

---Validate the entire configuration
---@param config QluelsConfig
---@return boolean valid
---@return string? error_message
M.validate = function(config)
  if type(config) ~= "table" then
    return false, "Configuration must be a table"
  end

  if config.backends ~= nil then
    if type(config.backends) ~= "table" then
      return false, "backends must be a table"
    end

    for name, backend in pairs(config.backends) do
      local valid, err = M.validate_backend(name, backend)
      if not valid then
        return false, "Backend '" .. name .. "': " .. err
      end
    end
  end

  if config.auto_attach ~= nil and type(config.auto_attach) ~= "boolean" then
    return false, "auto_attach must be a boolean"
  end

  if config.result_buffer ~= nil then
    if type(config.result_buffer) ~= "table" then
      return false, "result_buffer must be a table"
    end

    if config.result_buffer.position ~= nil then
      local valid_positions = { right = true, left = true, above = true, below = true }
      if not valid_positions[config.result_buffer.position] then
        return false, "result_buffer.position must be 'right', 'left', 'above', or 'below'"
      end
    end

    if config.result_buffer.size ~= nil and type(config.result_buffer.size) ~= "number" then
      return false, "result_buffer.size must be a number"
    end
  end

  return true, nil
end

---Current active configuration
---@type QluelsConfig
M.current = vim.deepcopy(M.defaults)

---Setup configuration by merging user options with defaults
---@param opts? QluelsConfig User configuration
---@return boolean success
---@return string? error_message
M.setup = function(opts)
  opts = opts or {}

  -- Validate user config
  local valid, err = M.validate(opts)
  if not valid then
    return false, "Invalid configuration: " .. err
  end

  -- Deep merge with defaults
  M.current = vim.tbl_deep_extend("force", M.defaults, opts)

  return true, nil
end

return M
