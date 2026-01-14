local constants = require("qluels.constants");
---LSP integration for qlue-ls custom actions
local M = {}

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
---Sends a qlueLs/addBackend notification
---@param params QluelsBackend Backend configuration
---@param bufnr? number Buffer number (0 or nil for current)
---@return boolean success Whether the notification was sent
M.add_backend = function(params, bufnr)
  bufnr = bufnr or 0

  local client = M.get_client(bufnr)
  if not client then
    vim.notify(string.format("%s is not attached to this buffer", constants.QLUE_IDENTITY), vim.log.levels.ERROR)
    return false
  end

  -- Send notification (fire-and-forget)
  client:notify("qlueLs/addBackend", params)
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

  local params = {}
  if backend_name then
    params.backendName = backend_name
  end

  client:request("qlueLs/pingBackend", params, function(err, result)
    if err then
      callback(false, err.message or "Unknown error")
    else
      callback(result == true, nil)
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

  client:notify("qlueLs/changeSettings", settings)
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

  client:request("qlueLs/defaultSettings", {}, function(err, result)
    if err then
      callback(nil, err.message or "Unknown error")
    else
      callback(result, nil)
    end
  end, bufnr)

  return true
end

---List all registered backends from the language server
---Sends a qlueLs/listBackends request
---@param callback fun(backends?: string[], err?: string) Callback with backend names
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

  client:request("qlueLs/listBackends", {}, function(err, result)
    if err then
      callback(nil, err.message or "Unknown error")
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
---@return boolean success Whether the request was sent
M.execute_operation = function(callback, bufnr, max_result_size, result_offset, access_token)
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

  client:request("qlueLs/executeOperation", params, function(err, result)
    if err then
      callback(nil, err.message or "Unknown error")
    else
      callback(result, nil)
    end
  end, bufnr)

  return true
end

return M
