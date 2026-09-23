-- Native qlue-ls protocol smoke test. Run from the repository root with:
-- nvim --headless -u NONE --cmd "set rtp+=$PWD" -l spec/integration.lua
local function fail(message)
  error("qlue-ls integration smoke test failed: " .. message)
end

local bufnr = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(bufnr)
vim.api.nvim_buf_set_name(bufnr, vim.fn.getcwd() .. "/qluels-integration.sparql")
vim.bo[bufnr].filetype = "sparql"
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "SELECT * WHERE {",
  "  ?s ?p ?o .",
  "}",
})

local client_id = vim.lsp.start({
  name = "qlue-ls",
  cmd = { "qlue-ls", "server" },
  root_dir = vim.fn.getcwd(),
}, { bufnr = bufnr })

if not client_id then fail("client did not start") end
if not vim.wait(10000, function()
  local client = vim.lsp.get_client_by_id(client_id)
  return client and client.initialized
end, 20) then
  fail("initialize timed out")
end

local client = assert(vim.lsp.get_client_by_id(client_id))
local function request(method, params)
  local response = client:request_sync(method, params, 10000, bufnr)
  if not response then fail(method .. " timed out") end
  if response.err then fail(method .. ": " .. vim.inspect(response.err)) end
  return response.result
end

request("qlueLs/addBackend", {
  name = "integration",
  url = "http://127.0.0.1:9/sparql",
  default = true,
  prefixMap = vim.empty_dict(),
  queries = vim.empty_dict(),
})

local backends = request("qlueLs/listBackends", vim.empty_dict())
local registered
for _, item in ipairs(backends) do
  if item.name == "integration" then registered = item end
end
if not registered or not registered.default then
  fail("unexpected listBackends response: " .. vim.inspect(backends))
end

local tree = request("qlueLs/parseTree", {
  textDocument = { uri = vim.uri_from_bufnr(bufnr) },
})
if not tree or not tree.tree then fail("parseTree did not return a tree") end

local jump = request("qlueLs/jump", {
  textDocument = { uri = vim.uri_from_bufnr(bufnr) },
  position = { line = 1, character = 2 },
  previous = false,
  options = { tabSize = 2, insertSpaces = true },
})
if not jump or type(jump.edits) ~= "table" then
  fail("unexpected jump response: " .. vim.inspect(jump))
end

client:stop(true)
print("qlue-ls 3.11.1 integration smoke test passed")
