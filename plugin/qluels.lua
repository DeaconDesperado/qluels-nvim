---Qluels plugin commands and autocommands
---This file is automatically loaded by Neovim

-- Prevent loading twice
if vim.g.loaded_qluels then
  return
end
vim.g.loaded_qluels = true

---Add a backend to qlue-ls
---Usage: :QluelsAddBackend {"service": {"name": "...", "url": "..."}, ...}
vim.api.nvim_create_user_command("QluelsAddBackend", function(opts)
  local ok, params = pcall(vim.fn.json_decode, opts.args)
  if not ok then
    vim.notify("Invalid JSON: " .. opts.args, vim.log.levels.ERROR)
    return
  end

  local lsp = require("qluels.lsp")
  local success = lsp.add_backend(params)

  if success then
    vim.notify("Backend added: " .. (params.service and params.service.name or "unknown"), vim.log.levels.INFO)
  end
end, {
  nargs = 1,
  desc = "Add a SPARQL backend to qlue-ls",
})

---Set the default backend
vim.api.nvim_create_user_command("QluelsSetBackend", function(opts)
  local backend_name = opts.args

  if backend_name == "" then
    vim.notify("Backend name is required", vim.log.levels.ERROR)
    return
  end

  local lsp = require("qluels.lsp")
  local success = lsp.update_default_backend(backend_name)

  if success then
    vim.notify("Default backend set to: " .. backend_name, vim.log.levels.INFO)
  end
end, {
  nargs = 1,
  desc = "Set the default SPARQL backend",
})

---Ping a backend to check availability
---Usage: :QLuelsPingBackend [backend_name]
vim.api.nvim_create_user_command("QLuelsPingBackend", function(opts)
  local backend_name = opts.args ~= "" and opts.args or nil

  local lsp = require("qluels.lsp")
  lsp.ping_backend(backend_name, function(available, err)
    if available then
      local name = backend_name or "default backend"
      vim.notify(name .. " is available", vim.log.levels.INFO)
    else
      local name = backend_name or "default backend"
      local error_msg = err or "unknown error"
      vim.notify(name .. " is not available: " .. error_msg, vim.log.levels.ERROR)
    end
  end)
end, {
  nargs = "?",
  desc = "Ping a SPARQL backend to check availability",
})

---Execute the current buffer as a SPARQL query
---Usage: :QluelsExecute [access_token]
vim.api.nvim_create_user_command("QluelsExecute", function(opts)
  local access_token = opts.args ~= "" and opts.args or nil

  local query = require("qluels.query")
  query.execute_buffer_query(access_token)
end, {
  nargs = "?",
  desc = "Execute the current buffer as a SPARQL query",
})

---Execute a visual selection as a SPARQL query
---Usage: :'<,'>QluelsExecuteSelection [backend_name]
vim.api.nvim_create_user_command("QluelsExecuteSelection", function(opts)
  local backend_name = opts.args ~= "" and opts.args or nil

  local query = require("qluels.query")
  query.execute_visual_query(backend_name)
end, {
  nargs = "?",
  range = true,
  desc = "Execute visual selection as a SPARQL query",
})

---Close the query results window
---Usage: :QluelsCloseResults
vim.api.nvim_create_user_command("QluelsCloseResults", function()
  local query = require("qluels.query")
  query.close_results()
  vim.notify("Query results closed", vim.log.levels.INFO)
end, {
  nargs = 0,
  desc = "Close the query results window",
})

---Reload the plugin (useful during development)
---Usage: :QluelsReload
vim.api.nvim_create_user_command("QluelsReload", function()
  local qluels = require("qluels")
  qluels.reload()
end, {
  nargs = 0,
  desc = "Reload the Qluels plugin (development)",
})

---Get default settings from qlue-ls
---Usage: :QluelsGetDefaultSettings
vim.api.nvim_create_user_command("QluelsGetDefaultSettings", function()
  local lsp = require("qluels.lsp")
  lsp.get_default_settings(function(settings, err)
    if err then
      vim.notify("Failed to get default settings: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("Default settings:\n" .. vim.inspect(settings), vim.log.levels.INFO)
    end
  end)
end, {
  nargs = 0,
  desc = "Get default settings from qlue-ls",
})
