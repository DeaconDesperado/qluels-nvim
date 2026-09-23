local constants = require("qluels.constants");
---LSP integration for qlue-ls custom actions
local M = {}

---@param err table|string|nil
---@return string
M.format_error = function(err)
  if type(err) == "string" then return err end
  if type(err) ~= "table" then return "Unknown error" end
  local parts = { err.message or "Request failed" }
  local data = err.data
  if type(data) == "table" then
    if data.type then table.insert(parts, "[" .. data.type .. "]") end
    local detail = data.exception or data.message or data.statusText
    if detail and detail ~= err.message then table.insert(parts, tostring(detail)) end
    if data.statusCode then
      table.insert(parts, string.format("HTTP %s%s", tostring(data.statusCode), data.statusText and (" " .. data.statusText) or ""))
    end
    if data.body and data.body ~= "" then table.insert(parts, tostring(data.body)) end
  end
  return table.concat(parts, ": ")
end

---@class ListBackendsResponse
---@field name string
---@field url string
---@field default boolean

---Get the qlue-ls client for the current buffer
---@param bufnr? number Buffer number (0 or nil for current)
---@return table? client The qlue-ls LSP client, or nil if not found
M.get_client = function(bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = constants.QLUE_IDENTITY })
  if #clients > 0 then
    return clients[1]
  end

  return nil
end

---Check if qlue-ls is attached to the current buffer
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean attached
M.is_attached = function(bufnr)
  return M.get_client(bufnr) ~= nil
end

---Add a backend to the qlue-ls language server
---Sends a qlueLs/addBackend request
---@param params QluelsBackend Backend configuration
---@param bufnr? number Buffer number (0 or nil for current)
---@param callback? fun(success: boolean, err?: string)
---@return boolean success Whether the request was sent
M.add_backend = function(params, bufnr, callback)
  bufnr = bufnr or 0

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  local wire_params = require("qluels.config").backend_to_wire(params)
  client:request("qlueLs/addBackend", wire_params, function(err)
    if callback then
      callback(err == nil, err and M.format_error(err) or nil)
    end
  end, bufnr)
  return true
end

---Update the default backend
---Sends a qlueLs/updateDefaultBackend notification
---@param backend_name string Name of the backend to set as default
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean success Whether the notification was sent
M.update_default_backend = function(backend_name, bufnr)
  bufnr = bufnr or 0

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  client:notify("qlueLs/updateDefaultBackend", {
    backendName = backend_name,
  })
  return true
end

---Ping a backend to check availability
---Sends a qlueLs/pingBackend request
---@param backend_name? string Name of the backend (nil for default)
---@param callback fun(available: boolean, err?: string) Callback with availability result
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean success Whether the request was sent
M.ping_backend = function(backend_name, callback, bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  local params = vim.empty_dict()
  if backend_name then
    params.backendName = backend_name
  end

  client:request("qlueLs/pingBackend", params, function(err, result)
    if err then
      callback(false, M.format_error(err))
    else
      callback(type(result) == "table" and result.available == true, nil)
    end
  end, bufnr)

  return true
end

---Change language server settings
---Sends a qlueLs/changeSettings notification
---@param settings table Settings object
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean success Whether the notification was sent
M.change_settings = function(settings, bufnr)
  bufnr = bufnr or 0

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  client:notify("qlueLs/changeSettings", require("qluels.config").settings_to_wire(settings))
  return true
end

---Get default settings from the language server
---Sends a qlueLs/defaultSettings request
---@param callback fun(settings?: table, err?: string) Callback with settings result
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean success Whether the request was sent
M.get_default_settings = function(callback, bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  client:request("qlueLs/defaultSettings", vim.empty_dict(), function(err, result)
    if err then
      callback(nil, M.format_error(err))
    else
      callback(result, nil)
    end
  end, bufnr)

  return true
end

---List all registered backends from the language server
---Sends a qlueLs/listBackends request
---@param callback fun(backends?: ListBackendsResponse[], err?: string) Callback with backend names
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean success Whether the request was sent
M.list_backends = function(callback, bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  client:request("qlueLs/listBackends", vim.empty_dict(), function(err, result)
    if err then
      callback(nil, M.format_error(err))
    else
      callback(result, nil)
    end
  end, bufnr)

  return true
end

---Execute a SPARQL query against a backend
---Sends a qlueLs/executeOperation request
---The query is read from the current buffer contents
---@param callback fun(result?: table, err?: string) Callback with query results
---@param bufnr? number Buffer number (0 or nil for current)
---@param max_result_size? number Maximum number of results to return
---@param result_offset? number Offset for result pagination
---@param access_token? string Access token to be forwarded to the backend
---@param query_id? string Optional query ID for cancellation support
---@return boolean success Whether the request was sent
M.execute_operation = function(callback, bufnr, max_result_size, result_offset, access_token, query_id)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  -- Build params according to ExecuteQueryParams schema
  local params = {
    textDocument = {
      uri = vim.uri_from_bufnr(bufnr)
    }
  }

  if max_result_size then
    params.maxResultSize = max_result_size
  end

  if result_offset then
    params.resultOffset = result_offset
  end

  if access_token then
    params.accessToken = access_token
  end

  if query_id then
    params.queryId = query_id
  end

  client:request("qlueLs/executeOperation", params, function(err, result)
    if err then
      callback(nil, M.format_error(err))
    else
      callback(result, nil)
    end
  end, bufnr)

  return true
end

---Execute an inline SPARQL query against the client attached to a context buffer.
---@param query string
---@param callback fun(result?: table, err?: string)
---@param opts? table {max_result_size?, result_offset?, access_token?, query_id?}
---@param bufnr? number Context buffer used to find the qlue-ls client
---@return boolean
M.execute_query = function(query, callback, opts, bufnr)
  opts = opts or {}
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  local params = { query = query }
  if opts.max_result_size then params.maxResultSize = opts.max_result_size end
  if opts.result_offset then params.resultOffset = opts.result_offset end
  if opts.access_token then params.accessToken = opts.access_token end
  if opts.query_id then params.queryId = opts.query_id end

  client:request("qlueLs/executeOperation", params, function(err, result)
    callback(result, err and M.format_error(err) or nil)
  end, bufnr)
  return true
end

---Get a backend summary. qlue-ls 3.11.1 emits an invalid JSON-RPC response for
---qlueLs/getBackend (both result and error:null), so derive the public
---name/url/default shape from listBackends instead.
---@param callback fun(backend?: table, err?: string) Callback with backend info
---@param bufnr? number Buffer number (0 or nil for current)
---@param backend_name? string Specific backend name (nil for default)
---@return boolean success Whether the request was sent
M.get_backend = function(callback, bufnr, backend_name)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  return M.list_backends(function(backends, err)
    if err then callback(nil, err); return end
    for _, backend in ipairs(backends or {}) do
      if (backend_name and backend.name == backend_name) or (not backend_name and backend.default) then
        callback(backend, nil)
        return
      end
    end
    callback(nil, backend_name and ("Backend not found: " .. backend_name) or "No default backend is configured")
  end, bufnr)
end

---Cancel a running SPARQL query
---Sends a qlueLs/cancelQuery notification
---@param query_id string The ID of the query to cancel
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean success Whether the notification was sent
M.cancel_query = function(query_id, bufnr)
  bufnr = bufnr or 0

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  client:notify("qlueLs/cancelQuery", {
    queryId = query_id,
  })
  return true
end

---@class JumpResult
---@field edits table[] Text edits against the request-time document
---@field position? {line: number, character: number} Position after applying edits

---Jump to the next or previous relevant position in the query
---Enables "tab navigation" within SPARQL queries
---Sends a qlueLs/jump request
---@param callback fun(result?: JumpResult, err?: string) Callback with jump result
---@param previous? boolean If true, jump to previous position instead of next
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean success Whether the request was sent
M.jump = function(callback, previous, bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(bufnr, cursor[1] - 1, cursor[1], false)[1] or ""
  local character = vim.str_utfindex(line, client.offset_encoding, cursor[2], false)
  local params = {
    textDocument = {
      uri = vim.uri_from_bufnr(bufnr)
    },
    position = {
      line = cursor[1] - 1, -- Convert to 0-indexed
      character = character,
    },
  }

  if previous then
    params.previous = true
  end

  params.options = {
    tabSize = vim.bo[bufnr].shiftwidth ~= 0 and vim.bo[bufnr].shiftwidth or vim.bo[bufnr].tabstop,
    insertSpaces = vim.bo[bufnr].expandtab,
  }

  client:request("qlueLs/jump", params, function(err, result)
    if err then
      callback(nil, M.format_error(err))
    else
      callback(result, nil)
    end
  end, bufnr)

  return true
end

---@alias OperationType "Query"|"Update"|"Unknown"

---Identify the operation type of the current SPARQL document
---Sends a qlueLs/identifyOperationType request
---@param callback fun(operation_type?: OperationType, err?: string) Callback with operation type
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean success Whether the request was sent
M.identify_operation_type = function(callback, bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  local params = {
    textDocument = {
      uri = vim.uri_from_bufnr(bufnr)
    }
  }

  client:request("qlueLs/identifyOperationType", params, function(err, result)
    if err then
      callback(nil, M.format_error(err))
    elseif result then
      callback(result.operationType, nil)
    else
      callback(nil, nil)
    end
  end, bufnr)

  return true
end

---Retrieve the parse tree for a SPARQL document
---Sends a qlueLs/parseTree request
---@param callback fun(result?: table, err?: string) Callback with parse tree result
---@param skip_trivia? boolean If true, omit trivia nodes from the tree
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean success Whether the request was sent
M.parse_tree = function(callback, skip_trivia, bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  local params = {
    textDocument = {
      uri = vim.uri_from_bufnr(bufnr)
    }
  }

  if skip_trivia then
    params.skipTrivia = true
  end

  client:request("qlueLs/parseTree", params, function(err, result)
    if err then
      callback(nil, M.format_error(err))
    else
      callback(result, nil)
    end
  end, bufnr)

  return true
end

return M
