# qluels-nvim

Neovim plugin for the [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) SPARQL language server.

## Features

- **Custom LSP Actions**: Support for qlue-ls custom LSP actions like `addBackend`, `updateBackend`, `pingBackend`, etc.
- **Query Execution**: Execute SPARQL queries from buffers with formatted table results
- **Backend Management**: Configure and manage multiple SPARQL endpoints, including via popular pickers (telescope, fzf-lua)
- **Query Library**: Maintain a project-local directory of saved SPARQL queries, browse them via pickers, and execute or load them
- **Parse Tree Viewer**: Inspect the SPARQL parse tree for debugging
- **On-Type Formatting**: Automatic formatting on `;`, `.` triggers (opt-in)
- **Settings Forwarding**: Push formatting/completion settings to qlue-ls on attach
- **Health Checks**: Integrated `:checkhealth` support

## Requirements

- Neovim 0.8.0 or later
- [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) v2.0+ language server
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
          name = "wikidata",
          url = "https://query.wikidata.org/sparql",
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
      name = "wikidata",
      url = "https://query.wikidata.org/sparql",
      healthCheckUrl = "https://query.wikidata.org/",  -- Optional
      requestMethod = "GET",  -- "GET" or "POST"
      default = true,         -- Set as default backend
      prefixMap = {           -- Optional prefix mappings
        wd = "http://www.wikidata.org/entity/",
        wdt = "http://www.wikidata.org/prop/direct/",
      },
    },
    dbpedia = {
      name = "dbpedia",
      url = "https://dbpedia.org/sparql",
      requestMethod = "POST",
    },
  },

  -- Enable on-type formatting (default: false)
  -- Typing ';' or '.' after a triple triggers automatic formatting
  on_type_formatting = false,

  -- Server settings pushed to qlue-ls on attach (optional)
  settings = {
    format = {
      keep_empty_lines = false,
      align_predicates = true,
    },
    auto_line_break = false,
  },

  -- Result buffer display configuration
  result_buffer = {
    position = "below",  -- "right", "left", "above", "below"
    size = nil,          -- nil for auto-size, or a number for fixed size
  },

  -- Query library directory, relative to project root (default: ".qluels")
  query_dir = ".qluels",
})
```

### Backend Configuration

See the [Qluels documentation](https://docs.qlue-ls.com/04_configuration/) for backend specific configuration.

Backends configured via lua configuration tables are additive to any defined in qlue-ls's own configuration (the
plugin calls `addBackend` for every entry).  This allows you to store project local backends in your repository's
`qlue-ls.[yml|toml]` while storing global ones in your nvim configuration.

### Query Library

The query library lets you maintain a directory of saved SPARQL queries alongside your project, similar to how other tools keep project-local configuration. By default, the plugin looks for `.sparql` and `.rq` files in a `.qluels/` directory at your project root.

```
my-project/
  .qluels/
    count-triples.sparql
    popular-artists.rq
    wikidata/
      city-population.sparql
  qlue-ls.yaml
  ...
```

Use `:QluelsLibraryExecute` to browse the library and run a query against the active backend, or `:QluelsLibraryLoad` to open a query file for editing. Both commands use your configured picker (telescope, fzf-lua, snacks, or the built-in `vim.ui.select` fallback). Subdirectories are supported and shown in the picker.

To use a different directory, set `query_dir` in your setup:

```lua
require("qluels").setup({
  query_dir = "sparql-queries",  -- relative to project root, or an absolute path
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:QluelsAddBackend {json}` | Add a SPARQL backend |
| `:QluelsListBackends` | List all registered backends (`*` marks default) |
| `:QluelsSetBackend {name}` | Set the default backend |
| `:QluelsSetBackend` | Without name specified, will launch your configured picker to choose backend |
| `:QLuelsPingBackend [{name}]` | Check backend availability |
| `:QluelsExecute [{accessToken}]` | Execute buffer as SPARQL query |
| `:QluelsExecuteSelection [{accessToken}]` | Execute visual selection as query |
| `:QluelsParseTree` | Display the SPARQL parse tree (use `!` to skip trivia) |
| `:QluelsLibraryExecute [{accessToken}]` | Pick a query from the library and execute it |
| `:QluelsLibraryLoad` | Pick a query from the library and open it in the current buffer |
| `:QluelsLibraryLoad!` | Pick a query from the library and open it in a split |
| `:QluelsCloseResults` | Close the results window |
| `:QluelsGetDefaultSettings` | Get qlue-ls default settings |
| `:QluelsReload` | Reload the plugin (development) |

### Usage Examples

```vim
" Add a new backend
:QluelsAddBackend {"name": "dbpedia", "url": "https://dbpedia.org/sparql", "default": true}

" Set active backend
:QluelsSetBackend wikidata

" Ping a backend
:QLuelsPingBackend wikidata

" Execute current buffer as a query
:QluelsExecute

" Execute visual selection
:'<,'>QluelsExecuteSelection

" View parse tree
:QluelsParseTree

" View parse tree without trivia (whitespace, comments)
:QluelsParseTree!

" Browse query library and execute a query
:QluelsLibraryExecute

" Browse query library and load a query into the current buffer
:QluelsLibraryLoad

" Browse query library and load a query in a split
:QluelsLibraryLoad!
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
   busted
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
- Query library directory
- Dependencies

## Related Projects

- [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) - SPARQL language server
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Lua test framework

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
