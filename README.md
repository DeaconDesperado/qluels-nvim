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
- **Navigation**: Server-aware jump, rename, references, document highlights, and folding
- **Health Checks**: Integrated `:checkhealth` support

## Requirements

- Neovim 0.11.0 or later
- [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) v3.11.1 or later
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

  -- Optional editor automation (both default to false)
  document_highlight = false,
  folding = false,

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

See the [Qlue-ls documentation](https://docs.qlue-ls.com/03_configuration/) for backend-specific configuration.

Backends configured via lua configuration tables are additive to any defined in qlue-ls's own configuration (the
plugin calls `addBackend` for every entry).  This allows you to store project local backends in your repository's
`qlue-ls.[yml|yaml|toml]` while storing global ones in your nvim configuration.

Lua server settings use the documented `snake_case` names above. The plugin converts them to the camelCase JSON
fields used by the qlue-ls runtime protocol. Backend fields and keys inside `queries` use their upstream camelCase
names.

Qlue-ls 3.x renamed variables exposed to custom completion and hover templates from `qlue_ls_*` to `qls_*`.
Qlue-ls 3.9 also upgraded to Tera v2: numeric access such as `prefix.0` must become `prefix[0]`, and Tera macros
must be migrated to components. Normal and custom completion queries remain fully supported by this plugin.

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

### Navigation and editor features

Qlue-ls 3.x supplies scoped rename, references, document highlights, folding ranges, and jump navigation. The plugin
does not install keymaps; map its commands however you prefer:

```lua
vim.keymap.set("n", "<Tab>", "<cmd>QluelsJump<cr>", { desc = "Next Qlue target" })
vim.keymap.set("n", "<S-Tab>", "<cmd>QluelsJump!<cr>", { desc = "Previous Qlue target" })
vim.keymap.set("n", "grn", "<cmd>QluelsRename<cr>", { desc = "Rename SPARQL variable" })
vim.keymap.set("n", "grr", "<cmd>QluelsReferences<cr>", { desc = "SPARQL references" })
```

Set `document_highlight = true` or `folding = true` in `setup()` to automate those features. Otherwise, use the
manual commands below. The `qlueLs/completionQuery` debugging notification is WASM-only upstream and is not emitted
by the native server launched by this plugin; normal and custom completions are unaffected.

## Commands

| Command | Description |
|---------|-------------|
| `:QluelsAddBackend {json}` | Add a SPARQL backend |
| `:QluelsListBackends` | List all registered backends (`*` marks default) |
| `:QluelsSetBackend {name}` | Set the default backend |
| `:QluelsSetBackend` | Without name specified, will launch your configured picker to choose backend |
| `:QluelsPingBackend [{name}]` | Check backend availability (`:QLuelsPingBackend` remains an alias) |
| `:QluelsExecute [{accessToken}]` | Execute buffer as SPARQL query |
| `:QluelsExecuteSelection [{accessToken}]` | Execute visual selection as query |
| `:QluelsParseTree` | Display the SPARQL parse tree (use `!` to skip trivia) |
| `:QluelsJump[!]` | Jump to the next server target (`!` for previous) |
| `:QluelsRename [{name}]` | Rename the variable under the cursor |
| `:QluelsReferences` | Show scoped variable references in the location list |
| `:QluelsHighlight` / `:QluelsClearHighlights` | Control document reference highlighting |
| `:QluelsFoldingEnable` / `:QluelsFoldingDisable` | Control LSP folding for the current buffer |
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
:QluelsPingBackend wikidata

" Execute current buffer as a query
:QluelsExecute

" Execute visual selection
:'<,'>QluelsExecuteSelection

" View parse tree
:QluelsParseTree

" View parse tree without trivia (whitespace, comments)
:QluelsParseTree!

" Navigate qlue-ls placeholders (use ! to move backwards)
:QluelsJump
:QluelsJump!

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
