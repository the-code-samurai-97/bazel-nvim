-- luacheck configuration for bazel-nvim.
std = "luajit"

read_globals = {
  "vim",
  "Snacks",
}

-- Match stylua.toml's column_width.
max_line_length = 120

-- LSP / Tree-sitter / picker callbacks carry many intentionally-unused params
-- (e.g. `function(_, item)`), and `self` in source objects.
unused_args = false
self = false

exclude_files = {
  "doc/",
  ".github/",
}
