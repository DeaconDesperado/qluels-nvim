local constants = require("qluels.constants")
local lsp = require("qluels.lsp")

local M = {}

local function client_for(bufnr)
  local client = lsp.get_client(bufnr)
  if not client then
    vim.notify(constants.QLUE_IDENTITY .. " is not attached to this buffer", vim.log.levels.ERROR)
  end
  return client
end

---Apply the server-side jump edits and move to its post-edit position.
---@param previous? boolean
---@param bufnr? number
M.jump = function(previous, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local client = client_for(bufnr)
  if not client then return end

  lsp.jump(function(result, err)
    if err then
      vim.notify("Qlue jump failed: " .. err, vim.log.levels.ERROR)
      return
    end
    if not result then return end

    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then return end
      vim.lsp.util.apply_text_edits(result.edits or {}, bufnr, client.offset_encoding)
      if not result.position then return end

      local wins = vim.fn.win_findbuf(bufnr)
      if #wins == 0 then return end
      local line = vim.api.nvim_buf_get_lines(bufnr, result.position.line, result.position.line + 1, false)[1] or ""
      local ok, byte_col = pcall(vim.str_byteindex, line, client.offset_encoding, result.position.character, false)
      vim.api.nvim_win_set_cursor(wins[1], { result.position.line + 1, ok and byte_col or result.position.character })
    end)
  end, previous, bufnr)
end

---@param new_name? string
---@param bufnr? number
M.rename = function(new_name, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local client = client_for(bufnr)
  if not client then return end

  local function request(name)
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    params.newName = name
    client:request("textDocument/rename", params, function(err, result)
      if err then
        vim.notify("Qlue rename failed: " .. (err.message or "Unknown error"), vim.log.levels.ERROR)
      elseif result then
        vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
      end
    end, bufnr)
  end

  if new_name and new_name ~= "" then
    request(new_name)
  else
    vim.ui.input({ prompt = "New variable name: " }, function(value)
      if value and value ~= "" then request(value) end
    end)
  end
end

---@param bufnr? number
M.references = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local client = client_for(bufnr)
  if not client then return end
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  params.context = { includeDeclaration = true }
  client:request("textDocument/references", params, function(err, result)
    if err then
      vim.notify("Qlue references failed: " .. (err.message or "Unknown error"), vim.log.levels.ERROR)
      return
    end
    local items = vim.lsp.util.locations_to_items(result or {}, client.offset_encoding)
    vim.fn.setloclist(0, {}, " ", { title = "Qlue references", items = items })
    if #items > 0 then vim.cmd("lopen") else vim.notify("No references found", vim.log.levels.INFO) end
  end, bufnr)
end

M.highlight = function()
  vim.lsp.buf.document_highlight()
end

M.clear_highlights = function()
  vim.lsp.buf.clear_references()
end

---@param bufnr? number
M.enable_folding = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    vim.wo[win].foldmethod = "expr"
    vim.wo[win].foldexpr = "v:lua.vim.lsp.foldexpr()"
  end
end

---@param bufnr? number
M.disable_folding = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    if vim.wo[win].foldexpr == "v:lua.vim.lsp.foldexpr()" then
      vim.wo[win].foldmethod = "manual"
      vim.wo[win].foldexpr = "0"
    end
  end
end

---@param bufnr number
---@param opts QluelsConfig
M.attach = function(bufnr, opts)
  if opts.document_highlight then
    local group = vim.api.nvim_create_augroup("QluelsDocumentHighlight_" .. bufnr, { clear = true })
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
      group = group, buffer = bufnr, callback = M.highlight,
    })
    vim.api.nvim_create_autocmd({ "CursorMoved", "InsertLeave", "BufLeave" }, {
      group = group, buffer = bufnr, callback = M.clear_highlights,
    })
  end

  if opts.folding then
    M.enable_folding(bufnr)
    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = vim.api.nvim_create_augroup("QluelsFolding_" .. bufnr, { clear = true }),
      buffer = bufnr,
      callback = function() M.enable_folding(bufnr) end,
    })
  end
end

return M
