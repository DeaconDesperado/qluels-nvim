# qluels-nvim

Enhanced Neovim plugin for the [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) SPARQL language server.

## Features

- **Custom LSP Actions**: Support for qlue-ls custom LSP actions like `addBackend`, `updateDefaultBackend`, `pingBackend`, etc.
- **Query Execution**: Execute SPARQL queries from buffers with formatted table results
- **Backend Management**: Configure and manage multiple SPARQL endpoints
- **Fast Development**: Hot-reload support for rapid iteration
- **Health Checks**: Integrated `:checkhealth` support
- **Well-Tested**: Comprehensive test suite using plenary.nvim

## Requirements

- Neovim 0.8.0 or later
- [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) language server
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (optional, for running tests)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/qluels-nvim",
  config = function()
    require("qluels").setup({
      backends = {
        wikidata = {
          service = {
            name = "wikidata",
            url = "https://query.wikidata.org/sparql",
          },
          default = true,
        },
      },
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "yourusername/qluels-nvim",
  config = function()
    require("qluels").setup()
  end,
}
```

### Local Development

```lua
{
  dir = "~/projects/foss/mgii/qluels-nvim",
  name = "qluels-nvim",
  config = function()
    require("qluels").setup()
  end,
}
```

## Configuration

```lua
require("qluels").setup({
  -- Pre-configured SPARQL backends
  backends = {
    wikidata = {
      service = {
        name = "wikidata",
        url = "https://query.wikidata.org/sparql",
        healthCheckUrl = "https://query.wikidata.org/",  -- Optional
      },
      requestMethod = "GET",  -- "GET" or "POST"
      default = true,         -- Set as default backend
      prefixMap = {           -- Optional prefix mappings
        wd = "http://www.wikidata.org/entity/",
        wdt = "http://www.wikidata.org/prop/direct/",
      },
    },
    dbpedia = {
      service = {
        name = "dbpedia",
        url = "https://dbpedia.org/sparql",
      },
      requestMethod = "POST",
    },
  },

  -- Automatically attach LSP to SPARQL files
  auto_attach = true,

  -- Result buffer display configuration
  result_buffer = {
    position = "below",  -- "right", "left", "above", "below"
    size = nil,          -- nil for auto-size, or a number for fixed size
  },
})
```

### Backend Configuration

Each backend must have:
- `service.name` (string): Unique identifier for the backend
- `service.url` (string): SPARQL endpoint URL

Optional fields:
- `service.healthCheckUrl` (string): URL for health checks
- `requestMethod` ("GET"|"POST"): HTTP method for queries
- `default` (boolean): Whether this is the default backend
- `prefixMap` (table): Prefix to URI mappings
- `queries` (table): Custom completion query templates

## Commands

| Command | Description |
|---------|-------------|
| `:QluelsAddBackend {json}` | Add a SPARQL backend |
| `:QluelsSetDefaultBackend {name}` | Set the default backend |
| `:QLuelsPingBackend [{name}]` | Check backend availability |
| `:QluelsExecuteQuery [{backend}]` | Execute buffer as SPARQL query |
| `:QluelsExecuteSelection [{backend}]` | Execute visual selection as query |
| `:QluelsCloseResults` | Close the results window |
| `:QluelsGetDefaultSettings` | Get qlue-ls default settings |
| `:QluelsReload` | Reload the plugin (development) |

### Usage Examples

```vim
" Add a new backend
:QluelsAddBackend {"service": {"name": "dbpedia", "url": "https://dbpedia.org/sparql"}, "default": true}

" Set default backend
:QluelsSetDefaultBackend wikidata

" Ping a backend
:QLuelsPingBackend wikidata

" Execute current buffer as a query
:QluelsExecuteQuery

" Execute visual selection
:'<,'>QluelsExecuteSelection wikidata
```

## Lua API

For programmatic access:

```lua
local qluels = require("qluels")

-- Add a backend
qluels.lsp.add_backend({
  service = {
    name = "mybackend",
    url = "http://localhost:3030/dataset/query",
  },
  default = true,
})

-- Update default backend
qluels.lsp.update_default_backend("mybackend")

-- Ping a backend
qluels.lsp.ping_backend("mybackend", function(available, err)
  if available then
    print("Backend is available!")
  else
    print("Backend error: " .. err)
  end
end)

-- Execute a query from current buffer
-- The query is read from the buffer by the server
qluels.lsp.execute_query(
  function(result, err)
    if result then
      print(vim.inspect(result))
    end
  end
  -- Optional: bufnr, max_result_size, result_offset
)

-- Execute buffer query
qluels.query.execute_buffer_query("mybackend")
```

## Development

### Hot Reloading

For fast iteration during development, use `:QluelsReload` to reload the plugin without restarting Neovim:

```vim
:QluelsReload
```

Or create a keybinding:

```lua
vim.keymap.set("n", "<leader>qr", "<cmd>QluelsReload<cr>", { desc = "Reload Qluels plugin" })
```

### Running Tests

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim):

```bash
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

Or run specific test files:

```bash
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/qluels/config_spec.lua"
```

### Health Check

Verify your setup:

```vim
:checkhealth qluels
```

This will check:
- Plugin setup status
- qlue-ls installation
- Configured backends
- LSP client attachment
- Dependencies

## Project Structure

```
qluels-nvim/
├── lua/qluels/
│   ├── init.lua          # Main module with setup()
│   ├── config.lua        # Configuration management
│   ├── lsp.lua           # LSP custom actions
│   ├── query.lua         # Query execution & display
│   └── health.lua        # Health check
├── plugin/qluels.lua     # Vim commands
├── tests/
│   ├── minimal_init.lua  # Test configuration
│   └── qluels/           # Test specs
├── doc/qluels.txt        # Vim help documentation
└── README.md
```

## Related Projects

- [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) - SPARQL language server
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Lua test framework

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
