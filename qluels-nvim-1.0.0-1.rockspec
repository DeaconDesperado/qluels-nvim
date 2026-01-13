rockspec_format = '3.0'
package = "qluels-nvim"
version = "1.0.0-1"
source = {
   url = "git+ssh://git@github.com/DeaconDesperado/qluels-nvim.git"
}
description = {
   detailed = "Neovim plugin for the [qlue-ls](https://github.com/IoannisNezis/Qlue-ls) SPARQL language server.",
   homepage = "https://github.com/DeaconDesperado/qluels-nvim",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      ["qluels.config"] = "lua/qluels/config.lua",
      ["qluels.constants"] = "lua/qluels/constants.lua",
      ["qluels.health"] = "lua/qluels/health.lua",
      ["qluels.init"] = "lua/qluels/init.lua",
      ["qluels.lsp"] = "lua/qluels/lsp.lua",
      ["qluels.query"] = "lua/qluels/query.lua"
   },
   copy_directories = {
      "doc",
      "tests"
   }
}
test_dependencies = {
  "nlua",
  "plenary.nvim"
}
