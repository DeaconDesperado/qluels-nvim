---Health check for qluels plugin
---Use with :checkhealth qluels
local M = {}

---Check if the plugin is properly set up
local function check_setup()
  if vim.g.qluels_setup_complete then
    vim.health.ok("Plugin setup() has been called")
  else
    vim.health.warn(
      "Plugin setup() has not been called",
      { "Add require('qluels').setup({}) to your Neovim configuration" }
    )
  end
end

---Check if qlue-ls executable is available
local function check_executable()
  if vim.fn.executable("qlue-ls") == 1 then
    vim.health.ok("qlue-ls executable found in PATH")

    -- Try to get version
    local handle = io.popen("qlue-ls --version 2>&1")
    if handle then
      local version = handle:read("*a")
      handle:close()
      if version and version ~= "" then
        vim.health.info("Version: " .. vim.trim(version))
      end
    end
  else
    vim.health.error(
      "qlue-ls executable not found in PATH",
      {
        "Install qlue-ls from https://github.com/IoannisNezis/Qlue-ls",
        "Or ensure the qlue-ls binary is in your PATH",
      }
    )
  end
end

---Check configured backends
local function check_backends()
  local ok, config = pcall(require, "qluels.config")
  if not ok then
    vim.health.error("Could not load qluels.config module")
    return
  end

  local backend_count = 0
  local default_backend = nil

  for name, backend in pairs(config.current.backends) do
    backend_count = backend_count + 1
    if backend.default then
      default_backend = name
    end
  end

  if backend_count > 0 then
    vim.health.ok(string.format("%d backend(s) configured", backend_count))

    if default_backend then
      vim.health.info("Default backend: " .. default_backend)
    else
      vim.health.warn("No default backend set")
    end

    -- List all backends
    for name, backend in pairs(config.current.backends) do
      local marker = backend.default and " (default)" or ""
      vim.health.info("  - " .. name .. marker .. ": " .. backend.service.url)
    end
  else
    vim.health.warn(
      "No backends configured",
      { "Add backends to your setup() configuration", "Or use :QluelsAddBackend to add backends at runtime" }
    )
  end
end

---Check LSP attachment
local function check_lsp()
  local clients = vim.lsp.get_clients({ name = "qlue_ls" })

  if #clients > 0 then
    vim.health.ok(string.format("qlue_ls LSP client active (%d instance(s))", #clients))
  else
    vim.health.info(
      "qlue_ls LSP client not currently attached",
      { "Open a SPARQL file to trigger LSP attachment", "Or manually start the LSP client" }
    )
  end
end

---Check dependencies
local function check_dependencies()
  -- Check for plenary if testing
  local has_plenary, _ = pcall(require, "plenary")
  if has_plenary then
    vim.health.ok("plenary.nvim is installed (for testing)")
  else
    vim.health.info(
      "plenary.nvim not found (optional, needed for running tests)",
      { "Install plenary.nvim for test support: nvim-lua/plenary.nvim" }
    )
  end
end

---Main health check function
M.check = function()
  vim.health.start("Qluels Plugin Health Check")

  check_setup()
  check_executable()
  check_backends()
  check_lsp()
  check_dependencies()
end

return M
