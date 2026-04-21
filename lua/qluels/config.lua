---@class QluelsFormatSettings
---@field align_predicates? boolean Align predicates in triple patterns (default: true)
---@field align_prefixes? boolean Align PREFIX declarations (default: false)
---@field separate_prologue? boolean Insert blank line after PREFIX/BASE declarations (default: false)
---@field capitalize_keywords? boolean Capitalize SPARQL keywords (default: true)
---@field insert_spaces? boolean Use spaces for indentation (default: true)
---@field tab_size? number Number of spaces per tab (default: 2)
---@field where_new_line? boolean Place WHERE on a new line (default: false)
---@field filter_same_line? boolean Keep FILTER on the same line as triple (default: true)
---@field compact? number|nil Compact format threshold (nil to disable)
---@field line_length? number Maximum line length before wrapping SELECT clause (default: 120)
---@field contract_triples? boolean Use semicolon shorthand for same-subject triples on format (default: false)
---@field keep_empty_lines? boolean Preserve intentional blank lines, collapsing consecutive ones (default: false)

---@class QluelsCompletionSettings
---@field timeout_ms? number Completion query timeout in milliseconds (default: 5000)
---@field result_size_limit? number Maximum completion results (default: 100)
---@field subject_completion_trigger_length? number Minimum chars before triggering subject completion (default: 3)
---@field object_completion_suffix? boolean Append " .\n" to object completions (default: true)
---@field variable_completion_limit? number|nil Max variable completions (nil for unlimited)
---@field same_subject_semicolon? boolean Transform same-subject completions to semicolon notation (default: true)

---@class QluelsPrefixesSettings
---@field add_missing? boolean Automatically add missing prefix declarations (default: true)
---@field remove_unused? boolean Automatically remove unused prefix declarations (default: false)

---@class QluelsReplacement
---@field pattern string Regex pattern to match
---@field replacement string Replacement string

---@class QluelsReplacementsSettings
---@field object_variable? QluelsReplacement[] Patterns for generating variable names from predicates

---@class QluelsSettings
---@field format? QluelsFormatSettings Formatter settings
---@field completion? QluelsCompletionSettings Completion settings
---@field prefixes? QluelsPrefixesSettings Prefix management settings
---@field replacements? QluelsReplacementsSettings Variable name replacement patterns
---@field auto_line_break? boolean Auto-insert line break after ; or . following valid triple (default: false)

---@class QluelsConfig
---@field server QluelsServer Settings for the language server itself
---@field backends? table<string, QluelsBackend> Pre-configured backends
---@field auto_attach? boolean Automatically attach LSP to SPARQL files
---@field result_buffer? QluelsResultBufferConfig Result buffer display options
---@field on_type_formatting? boolean Enable on-type formatting (default: false)
---@field semantic_highlighting? boolean Enable semantic token highlighting (default: true)
---@field settings? QluelsSettings Server settings to push on attach

---@class QluelsServer
---@field capabilities? table|nil The client capabilities.
---@field filetypes? table The filetypes to activate for by default
---@field on_attach fun(client: vim.lsp.Client, bufnr: number) | nil The function executed when the LSP client attaches to a buffer.

---@alias QluelsEngine "QLever"|"GraphDB"|"Virtuoso"|"MillenniumDB"|"Blazegraph"|"Jena"

---@class QluelsBackend
---@field name string Backend identifier
---@field url string SPARQL endpoint URL
---@field healthCheckUrl? string Optional health check URL
---@field engine? QluelsEngine SPARQL engine type for engine-specific optimizations
---@field requestMethod? "GET"|"POST" HTTP method for queries
---@field default? boolean Set as default backend
---@field prefixMap? table<string, string> Prefix mappings
---@field queries? table<string, string> Completion query templates
---@field additionalData? table Arbitrary data to attach to the backend

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
  on_type_formatting = false,
  semantic_highlighting = true,
  settings = nil,
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

  if type(backend.name) ~= "string" or backend.name == "" then
    return false, "Backend name must be a non-empty string"
  end

  if type(backend.url) ~= "string" or backend.url == "" then
    return false, "Backend url must be a non-empty string"
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

  if backend.additionalData ~= nil and type(backend.additionalData) ~= "table" then
    return false, "Backend additionalData must be a table"
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

  if config.on_type_formatting ~= nil and type(config.on_type_formatting) ~= "boolean" then
    return false, "on_type_formatting must be a boolean"
  end

  if config.semantic_highlighting ~= nil and type(config.semantic_highlighting) ~= "boolean" then
    return false, "semantic_highlighting must be a boolean"
  end

  if config.settings ~= nil and type(config.settings) ~= "table" then
    return false, "settings must be a table"
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
