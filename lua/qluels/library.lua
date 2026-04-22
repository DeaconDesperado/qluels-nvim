---Query library: browse, load, and execute saved SPARQL queries from a project directory
local config = require("qluels.config")
local lsp = require("qluels.lsp")
local query = require("qluels.query")
local picker = require("qluels.picker")

local M = {}

---Resolve the query directory to an absolute path
---@param bufnr? number Buffer for context (used to find project root)
---@return string? path Absolute path to query directory, or nil if not found
M.resolve_query_dir = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local query_dir = config.current.query_dir

  if vim.startswith(query_dir, "/") then
    return query_dir
  end

  local root = vim.fs.root(bufnr, { ".git" }) or vim.fn.getcwd()
  return root .. "/" .. query_dir
end

---Discover SPARQL query files in the query directory
---@param bufnr? number Buffer for context
---@return QueryFileItem[]? items List of query file items, or nil if directory doesn't exist
M.discover_queries = function(bufnr)
  local dir = M.resolve_query_dir(bufnr)
  if not dir or vim.fn.isdirectory(dir) == 0 then
    return nil
  end

  local files = vim.fs.find(function(name)
    return name:match("%.sparql$") or name:match("%.rq$")
  end, { path = dir, type = "file", limit = math.huge })

  local items = {}
  for _, file_path in ipairs(files) do
    local relative = file_path:sub(#dir + 2)
    local name = vim.fn.fnamemodify(file_path, ":t:r")
    table.insert(items, {
      name = name,
      path = file_path,
      relative_path = relative,
    })
  end

  table.sort(items, function(a, b) return a.relative_path < b.relative_path end)
  return items
end

---Execute a query file against the current backend
---@param file_path string Absolute path to the SPARQL file
---@param access_token? string Optional access token
M.execute_file_query = function(file_path, access_token)
  local lines = {}
  local file = io.open(file_path, "r")
  if not file then
    vim.notify("Cannot open file: " .. file_path, vim.log.levels.ERROR)
    return
  end
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()

  if #lines == 0 then
    vim.notify("Query file is empty: " .. file_path, vim.log.levels.WARN)
    return
  end

  local display_name = vim.fn.fnamemodify(file_path, ":t")
  vim.notify("Executing " .. display_name .. "...", vim.log.levels.INFO)

  local temp_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "sparql", { buf = temp_buf })

  lsp.execute_operation(function(result, err)
    vim.api.nvim_buf_delete(temp_buf, { force = true })

    if err then
      vim.notify("Query execution failed: " .. err, vim.log.levels.ERROR)
      return
    end

    if result then
      query.display_results(result)
      vim.notify(display_name .. " executed successfully", vim.log.levels.INFO)
    else
      vim.notify("Query returned no results", vim.log.levels.WARN)
    end
  end, temp_buf, nil, nil, access_token)
end

---Load a query file into a buffer
---@param file_path string Absolute path to the SPARQL file
---@param open_in_split? boolean If true, open in a new split
M.load_query_file = function(file_path, open_in_split)
  if open_in_split then
    vim.cmd("split " .. vim.fn.fnameescape(file_path))
  else
    vim.cmd("edit " .. vim.fn.fnameescape(file_path))
  end
end

---Open the query library picker for execution
---@param access_token? string Optional access token
M.pick_and_execute = function(access_token)
  local items = M.discover_queries()
  if not items or #items == 0 then
    local dir = M.resolve_query_dir()
    vim.notify("No queries found in " .. (dir or config.current.query_dir), vim.log.levels.WARN)
    return
  end

  picker.pick_query(items, {
    prompt = "Execute Query",
    on_select = function(item)
      M.execute_file_query(item.path, access_token)
    end,
  })
end

---Open the query library picker for loading
---@param open_in_split? boolean If true, open selected query in a new split
M.pick_and_load = function(open_in_split)
  local items = M.discover_queries()
  if not items or #items == 0 then
    local dir = M.resolve_query_dir()
    vim.notify("No queries found in " .. (dir or config.current.query_dir), vim.log.levels.WARN)
    return
  end

  picker.pick_query(items, {
    prompt = "Load Query",
    on_select = function(item)
      M.load_query_file(item.path, open_in_split)
    end,
  })
end

return M
