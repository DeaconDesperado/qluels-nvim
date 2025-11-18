---SPARQL query execution and result display
local lsp = require("qluels.lsp")
local config = require("qluels.config")

local M = {}

---Buffer for displaying query results
---@type number?
M.result_bufnr = nil

---Window for displaying query results
---@type number?
M.result_winnr = nil

---Create or show the result buffer
---@return number bufnr The buffer number
---@return number winnr The window number
M.create_result_buffer = function()
  -- Reuse existing buffer if it's still valid
  if M.result_bufnr and vim.api.nvim_buf_is_valid(M.result_bufnr) then
    -- Check if window is still valid
    if M.result_winnr and vim.api.nvim_win_is_valid(M.result_winnr) then
      return M.result_bufnr, M.result_winnr
    end
  else
    -- Create new buffer
    M.result_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.result_bufnr, "qluels://results")

    -- Set buffer options
    vim.api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = M.result_bufnr})
    vim.api.nvim_set_option_value("swapfile", false, { scope = "local", buf = M.result_bufnr})
    vim.api.nvim_set_option_value("filetype", "qluels-results", { scope = "local", buf = M.result_bufnr})
    vim.api.nvim_set_option_value("bufhidden", "hide", { scope = "local", buf = M.result_bufnr})
  end

  -- Create window with split
  local position = config.current.result_buffer.position
  local size = config.current.result_buffer.size

  local split_cmd
  if position == "right" then
    split_cmd = "vertical rightbelow split"
  elseif position == "left" then
    split_cmd = "vertical leftabove split"
  elseif position == "above" then
    split_cmd = "leftabove split"
  else -- below
    split_cmd = "rightbelow split"
  end

  vim.cmd(split_cmd)
  M.result_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.result_winnr, M.result_bufnr)

  -- Set window size if specified
  if size then
    if position == "right" or position == "left" then
      vim.api.nvim_win_set_width(M.result_winnr, size)
    else
      vim.api.nvim_win_set_height(M.result_winnr, size)
    end
  end

  return M.result_bufnr, M.result_winnr
end

---Format query results in expanded display format (like psql \x)
---@param results table Query results from LSP server
---@param viewport_width? number Width of the viewport (default: 80)
---@return string[] lines Formatted result lines
M.format_results = function(results, viewport_width)
  local lines = {}
  viewport_width = viewport_width or 80

  -- Handle different result formats
  -- This is a placeholder - actual format depends on what qlue-ls returns
  if type(results) == "table" then
    -- Check if it's a SPARQL results format
    if results.head and results.results then
      -- Standard SPARQL JSON results format
      local vars = results.head.vars or {}
      local bindings = results.results.bindings or {}

      if #vars == 0 then
        table.insert(lines, "No variables in result set")
        return lines
      end

      -- Find the longest variable name for alignment
      local max_var_width = 0
      for _, var in ipairs(vars) do
        max_var_width = math.max(max_var_width, #var + 1) -- +1 for the '?' prefix
      end

      -- Format each record in expanded display format
      for i, binding in ipairs(bindings) do
        -- Record separator line
        local separator = string.format("-[ RECORD %d ]", i)
        separator = separator .. string.rep("-", math.max(0, 60 - #separator))
        table.insert(lines, separator)

        -- Each variable on its own line
        for _, var in ipairs(vars) do
          local var_name = "?" .. var
          local value = ""

          if binding[var] then
            value = binding[var].value or ""
          end

          -- Pad variable name to align values
          local padded_var = string.format("%-" .. max_var_width .. "s", var_name)

          -- Handle long values - wrap if needed
          local first_line_width = viewport_width - max_var_width - 3 -- 3 for " | "
          local cont_line_width = viewport_width - max_var_width - 3 -- Same for continuation

          if #value <= first_line_width or first_line_width <= 0 then
            -- Value fits on one line (or no room for wrapping)
            table.insert(lines, padded_var .. " | " .. value)
          else
            -- Need to wrap value across multiple lines
            local remaining = value
            local is_first = true

            while #remaining > 0 do
              local chunk_width = is_first and first_line_width or cont_line_width
              if chunk_width <= 0 then
                chunk_width = viewport_width -- Fallback for very long var names
              end

              local chunk = remaining:sub(1, chunk_width)
              remaining = remaining:sub(chunk_width + 1)

              if is_first then
                table.insert(lines, padded_var .. " | " .. chunk)
                is_first = false
              else
                -- Continuation lines: indent to align with value column and include separator
                local indent = string.rep(" ", max_var_width)
                table.insert(lines, indent .. " | " .. chunk)
              end
            end
          end
        end
      end

      -- Add summary
      table.insert(lines, "")
      table.insert(lines, string.format("(%d rows)", #bindings))
    else
      -- Unknown format - just stringify it
      table.insert(lines, "Results:")
      table.insert(lines, vim.inspect(results))
    end
  else
    table.insert(lines, "Unexpected result type: " .. type(results))
    table.insert(lines, tostring(results))
  end

  return lines
end

---Display results in the result buffer
---@param results table Query results
M.display_results = function(results)
  local bufnr, winnr = M.create_result_buffer()

  -- Get viewport width from the window
  local viewport_width = 80 -- default
  if winnr and vim.api.nvim_win_is_valid(winnr) then
    viewport_width = vim.api.nvim_win_get_width(winnr)
  end

  -- Format results with viewport width
  local lines = M.format_results(results, viewport_width)

  -- Set buffer content
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "modified", false)
end

---Execute the SPARQL query in the current buffer
---@param backend_name? string Backend name (nil for default)
---@param bufnr? number Source buffer number (0 or nil for current)
M.execute_buffer_query = function(backend_name, bufnr)
  bufnr = bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- Check if buffer is empty
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local query = table.concat(lines, "\n")

  if query == "" then
    vim.notify("Buffer is empty", vim.log.levels.WARN)
    return
  end

  vim.notify("Executing query...", vim.log.levels.INFO)

  -- Server reads query from the text document itself
  lsp.execute_query(function(result, err)
    if err then
      vim.notify("Query execution failed: " .. err, vim.log.levels.ERROR)
      return
    end

    if result then
      M.display_results(result)
      vim.notify("Query executed successfully", vim.log.levels.INFO)
    else
      vim.notify("Query returned no results", vim.log.levels.WARN)
    end
  end, bufnr)
end

---Execute a visual selection as a SPARQL query
---Creates a temporary buffer with the selection and executes it
---@param backend_name? string Backend name (nil for default)
M.execute_visual_query = function(backend_name)
  -- Get visual selection
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2] - 1
  local end_line = end_pos[2]

  local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false)
  local query = table.concat(lines, "\n")

  if query == "" then
    vim.notify("Selection is empty", vim.log.levels.WARN)
    return
  end

  vim.notify("Executing query...", vim.log.levels.INFO)

  -- Create a temporary scratch buffer with the selected query
  local temp_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(temp_buf, 'filetype', 'sparql')

  -- Execute query from the temporary buffer
  lsp.execute_query(function(result, err)
    -- Clean up temporary buffer
    vim.api.nvim_buf_delete(temp_buf, { force = true })

    if err then
      vim.notify("Query execution failed: " .. err, vim.log.levels.ERROR)
      return
    end

    if result then
      M.display_results(result)
      vim.notify("Query executed successfully", vim.log.levels.INFO)
    else
      vim.notify("Query returned no results", vim.log.levels.WARN)
    end
  end, temp_buf)
end

---Close the result buffer window
M.close_results = function()
  if M.result_winnr and vim.api.nvim_win_is_valid(M.result_winnr) then
    vim.api.nvim_win_close(M.result_winnr, false)
    M.result_winnr = nil
  end
end

return M
