# qluels-nvim

Neovim plugin for the [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) SPARQL language server.

## Features

- **Custom LSP Actions**: Support for qlue-ls custom LSP actions like `addBackend`, `updateBackend`, `pingBackend`, etc.
- **Query Execution**: Execute SPARQL queries from buffers with formatted table results
- **Backend Management**: Configure and manage multiple SPARQL endpoints
- **Health Checks**: Integrated `:checkhealth` support

## Requirements

- Neovim 0.8.0 or later
- [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) language server
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (optional, for running tests)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "DeaconDesperado/qluels-nvim",
  config = function()
    require("qluels").setup({
      auto_attach = true,
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
  "DeaconDesperado/qluels-nvim",
  config = function()
    require("qluels").setup()
  end,
}
```

## Configuration

```lua
require("qluels").setup({
  -- Pre-configured SPARQL backends
  auto_attach = true,
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

See the [Qluels documentation](https://docs.qlue-ls.com/04_configuration/) for backend specific configuration.

Backends configured via lua configuration tables are additive to any defined in qlue-ls's own configuration (the 
plugin calls `addBackend` for every entry).

## Commands

| Command | Description |
|---------|-------------|
| `:QluelsAddBackend {json}` | Add a SPARQL backend |
| `:QluelsSetBackend {name}` | Set the default backend |
| `:QLuelsPingBackend [{name}]` | Check backend availability |
| `:QluelsExecute [{accessToken}]` | Execute buffer as SPARQL query.|
| `:QluelsExecuteSelection [{accessToken}]` | Execute visual selection as query. |
| `:QluelsCloseResults` | Close the results window |
| `:QluelsGetDefaultSettings` | Get qlue-ls default settings |
| `:QluelsReload` | Reload the plugin (development) |

### Usage Examples

```vim
" Add a new backend
:QluelsAddBackend {"service": {"name": "dbpedia", "url": "https://dbpedia.org/sparql"}, "default": true}

" Set active backend
:QluelsSetBackend wikidata

" Ping a backend
:QLuelsPingBackend wikidata

" Execute current buffer as a query
:QluelsExecuteQuery

" Execute visual selection
:'<,'>QluelsExecuteSelection wikidata
```
## Development

### Hot Reloading

For fast iteration during development, use `:QluelsReload` to reload the plugin without restarting Neovim:

```vim
:QluelsReload
```

### Running Tests

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) and [busted](https://github.com/lunarmodules/busted) :

```bash
   busted tests/ 
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

## Related Projects

- [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) - SPARQL language server
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Lua test framework

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
