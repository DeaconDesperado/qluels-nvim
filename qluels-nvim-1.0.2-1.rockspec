rockspec_format = '3.0'
package = "qluels-nvim"
version = "1.0.2-1"
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
   copy_directories = {
      "doc",
      "lua"
   }
}
test_dependencies = {
  "nlua",
  "plenary.nvim"
}

test = {
  type = "busted"
}
