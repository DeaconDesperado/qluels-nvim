---Health check for qluels plugin
---Use with :checkhealth qluels
local constants = require("qluels.constants")
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

    local handle = io.popen("qlue-ls --version 2>&1")
    if handle then
      local version_output = handle:read("*a")
      handle:close()
      if version_output and version_output ~= "" then
        local version_str = vim.trim(version_output)
        vim.health.info("Version: " .. version_str)

        local major, minor, patch = version_str:match("(%d+)%.(%d+)%.(%d+)")
        if major then
          major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
          if major < 2 or (major == 2 and minor < 6) then
            vim.health.warn(
              string.format("qlue-ls %d.%d.%d is older than 2.6.0; some features (semantic tokens) are unavailable", major, minor, patch),
              { "Update qlue-ls to 2.6.0 or later for full feature support" }
            )
          end
        end
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
      vim.health.info("  - " .. name .. marker .. ": " .. backend.url)
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
  local clients = vim.lsp.get_clients({ name = constants.QLUE_IDENTITY })

  if #clients > 0 then
    vim.health.ok(string.format("%s LSP client active (%d instance(s))", constants.QLUE_IDENTITY, #clients))
  else
    vim.health.info(
      string.format("%s LSP client not currently attached", constants.QLUE_IDENTITY),
      { "Open a SPARQL file to trigger LSP attachment", "Or manually start the LSP client" }
    )
  end
end

---Check semantic token support
local function check_semantic_tokens()
  local ok, cfg = pcall(require, "qluels.config")
  if not ok then return end

  if cfg.current.semantic_highlighting == false then
    vim.health.info("Semantic highlighting is disabled in configuration")
    return
  end

  local clients = vim.lsp.get_clients({ name = constants.QLUE_IDENTITY })
  if #clients == 0 then
    vim.health.info("No active qlue-ls client to check semantic tokens (open a SPARQL file first)")
    return
  end

  for _, client in ipairs(clients) do
    local caps = client.server_capabilities
    if caps and caps.semanticTokensProvider then
      vim.health.ok("Semantic tokens: server advertises support")
      if caps.semanticTokensProvider.legend then
        local types = caps.semanticTokensProvider.legend.tokenTypes or {}
        vim.health.info("  Token types: " .. table.concat(types, ", "))
      end
      return
    end
  end

  vim.health.warn("Semantic tokens: server does not advertise support (upgrade to qlue-ls >= 2.6.0)")
end

---Check query library directory
local function check_query_library()
  local ok, library = pcall(require, "qluels.library")
  if not ok then
    vim.health.error("Could not load qluels.library module")
    return
  end

  local dir = library.resolve_query_dir()
  if dir and vim.fn.isdirectory(dir) == 1 then
    local items = library.discover_queries()
    local count = items and #items or 0
    vim.health.ok(string.format("Query library: %s (%d queries)", dir, count))
  else
    vim.health.info(
      "Query library directory not found: " .. (dir or "?"),
      { "Create the directory or configure query_dir in setup()" }
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
  check_semantic_tokens()
  check_query_library()
  check_dependencies()
end

return M
