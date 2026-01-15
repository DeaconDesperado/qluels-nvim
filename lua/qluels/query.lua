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
    vim.api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = M.result_bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { scope = "local", buf = M.result_bufnr })
    vim.api.nvim_set_option_value("filetype", "qluels-results", { scope = "local", buf = M.result_bufnr })
    vim.api.nvim_set_option_value("bufhidden", "hide", { scope = "local", buf = M.result_bufnr })
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
---@return table highlights List of highlight entries {line, col_start, col_end, hl_group}
M.format_results = function(results, viewport_width)
  local lines = {}
  local highlights = {}
  local queryResults = results.queryResult
  viewport_width = viewport_width or 80

  if type(queryResults) == "table" then
    -- Check if it's a SPARQL results format
    if queryResults.result.head and queryResults.result.results then
      local vars = queryResults.result.head.vars or {}
      local bindings = queryResults.result.results.bindings or {}

      if #vars == 0 then
        table.insert(lines, "No variables in result set")
        return lines, highlights
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
        for var_idx, var in ipairs(vars) do
          local var_name = "?" .. var
          local value = ""

          if binding[var] then
            value = binding[var].value or ""
          end

          -- Determine highlight group (cycle through available groups)
          local hl_group = "QluelsVar" .. ((var_idx - 1) % 8 + 1)

          -- Pad variable name to align values
          local padded_var = string.format("%-" .. max_var_width .. "s", var_name)

          -- Split value by newlines first to handle embedded newlines
          -- Normalize line endings to \n, then split
          local normalized = value:gsub("\r\n", "\n"):gsub("\r", "\n")
          local value_lines = {}

          -- Split on newlines
          local start_idx = 1
          while true do
            local newline_idx = normalized:find("\n", start_idx, true)
            if newline_idx then
              table.insert(value_lines, normalized:sub(start_idx, newline_idx - 1))
              start_idx = newline_idx + 1
            else
              -- Last line (or only line if no newlines)
              table.insert(value_lines, normalized:sub(start_idx))
              break
            end
          end

          -- Handle long values - wrap if needed
          local first_line_width = viewport_width - max_var_width - 3 -- 3 for " | "
          local cont_line_width = viewport_width - max_var_width - 3  -- Same for continuation

          local is_first = true
          for _, value_line in ipairs(value_lines) do
            if #value_line <= first_line_width or first_line_width <= 0 then
              -- Value line fits (or no room for wrapping)
              if is_first then
                local line = padded_var .. " | " .. value_line
                table.insert(lines, line)
                -- Highlight entire line
                table.insert(highlights, {
                  line = #lines - 1,
                  col_start = 0,
                  col_end = #line,
                  hl_group = hl_group
                })
                is_first = false
              else
                -- Continuation lines: indent to align with value column and include separator
                local indent = string.rep(" ", max_var_width)
                local line = indent .. " | " .. value_line
                table.insert(lines, line)
                -- Highlight entire continuation line
                table.insert(highlights, {
                  line = #lines - 1,
                  col_start = 0,
                  col_end = #line,
                  hl_group = hl_group
                })
              end
            else
              -- Need to wrap value line across multiple lines
              local remaining = value_line

              while #remaining > 0 do
                local chunk_width = is_first and first_line_width or cont_line_width
                if chunk_width <= 0 then
                  chunk_width = viewport_width -- Fallback for very long var names
                end

                local chunk = remaining:sub(1, chunk_width)
                remaining = remaining:sub(chunk_width + 1)

                if is_first then
                  local line = padded_var .. " | " .. chunk
                  table.insert(lines, line)
                  -- Highlight entire line
                  table.insert(highlights, {
                    line = #lines - 1,
                    col_start = 0,
                    col_end = #line,
                    hl_group = hl_group
                  })
                  is_first = false
                else
                  -- Continuation lines: indent to align with value column and include separator
                  local indent = string.rep(" ", max_var_width)
                  local line = indent .. " | " .. chunk
                  table.insert(lines, line)
                  -- Highlight entire continuation line
                  table.insert(highlights, {
                    line = #lines - 1,
                    col_start = 0,
                    col_end = #line,
                    hl_group = hl_group
                  })
                end
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

  return lines, highlights
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

  local highlight_groups = {
    "Identifier",
    "Statement",
    "Type",
    "Function",
    "Constant",
    "ErrorMsg",
    "Special",
  }

  for i, group in ipairs(highlight_groups) do
    vim.api.nvim_set_hl(0, "QluelsVar" .. i, { link = group })
  end

  -- Format results with viewport width
  local lines, highlights = M.format_results(results, viewport_width)

  -- Ensure no line contains newlines (flatten any that slipped through)
  -- and track line mapping for highlights
  local sanitized_lines = {}
  local line_mapping = {} -- maps old line index to new line index
  for old_idx, line in ipairs(lines) do
    line_mapping[old_idx - 1] = #sanitized_lines -- 0-indexed for highlights
    -- Split any remaining newlines in this line
    for subline in (line .. "\n"):gmatch("([^\r\n]*)\n") do
      if subline ~= "" or #sanitized_lines == 0 then
        table.insert(sanitized_lines, subline)
      end
    end
  end

  -- Set buffer content
  vim.api.nvim_set_option_value("modifiable", true, { scope = "local", buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, sanitized_lines)

  -- Apply highlights with adjusted line numbers
  local ns_id = vim.api.nvim_create_namespace("qluels_results")
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  for _, hl in ipairs(highlights) do
    local new_line = line_mapping[hl.line]
    if new_line and new_line < #sanitized_lines then
      vim.api.nvim_buf_set_extmark(
        bufnr,
        ns_id,
        new_line,
        hl.col_start,
        { end_col = hl.col_end, hl_group = hl.hl_group }
      )
    end
  end

  -- Debug: Add a command to inspect highlights
  vim.api.nvim_buf_create_user_command(bufnr, "QluelsDebugHighlights", function()
    print("=== Qluels Highlight Debug ===")
    print(string.format("Buffer: %d", bufnr))
    print(string.format("Namespace ID: %d", ns_id))
    print(string.format("Number of highlights applied: %d", #highlights))

    -- Check buffer settings
    local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    local syntax = vim.api.nvim_get_option_value("syntax", { buf = bufnr })
    print(string.format("Buffer filetype: %s", ft))
    print(string.format("Buffer syntax: %s", syntax))

    -- Check if highlight groups exist and what they resolve to
    for i = 1, 8 do
      local hl_name = "QluelsVar" .. i
      local hl_def = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
      local hl_def_with_link = vim.api.nvim_get_hl(0, { name = hl_name })
      if next(hl_def) then
        print(string.format("✓ %s resolves to: %s", hl_name, vim.inspect(hl_def)))
      elseif next(hl_def_with_link) then
        print(string.format("✓ %s linked: %s", hl_name, vim.inspect(hl_def_with_link)))
      else
        print(string.format("✗ %s NOT defined", hl_name))
      end
    end

    -- Check extmarks in buffer
    local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
    print(string.format("\nExtmarks in buffer: %d", #extmarks))
    if #extmarks > 0 then
      for i, extmark in ipairs(extmarks) do
        local id, row, col, details = extmark[1], extmark[2], extmark[3], extmark[4]
        print(string.format("  [%d] row=%d, col=%d-%d, hl_group=%s",
          id, row, col, details.end_col or -1, details.hl_group or "none"))
        if i >= 5 then
          print(string.format("  ... and %d more", #extmarks - 5))
          break
        end
      end
    else
      print("  No extmarks found!")
    end
  end, {})

  vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = bufnr })
  vim.api.nvim_set_option_value("modified", false, { scope = "local", buf = bufnr })
  vim.keymap.set("n", "q", "<cmd>quit<CR>", { buffer = bufnr, silent = true });
end

---Execute the SPARQL query in the current buffer
---@param access_token? string Backend name (nil for default)
---@param bufnr? number Source buffer number (0 or nil for current)
M.execute_buffer_query = function(access_token, bufnr)
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
  lsp.execute_operation(function(result, err)
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
  vim.api.nvim_set_option_value('filetype', 'sparql', { buf = temp_buf })

  -- Execute query from the temporary buffer
  lsp.execute_operation(function(result, err)
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
