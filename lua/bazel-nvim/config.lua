local M = {}

---@class bazel.Config
local defaults = {
  -- Document symbols: list cc_binary / cc_library / py_binary / cuda_library /
  -- ... targets (by name + rule type) in `<leader>ss`, outline and breadcrumbs.
  -- Implemented as a tiny in-process LSP server (no external binary required).
  symbols = true,

  -- Suppress the `starpls` language server's own (weaker, untyped) document
  -- symbols so targets are not listed twice. No-op if starpls isn't running.
  suppress_starpls_symbols = true,

  -- Create the `:Bazel*` user commands.
  commands = true,

  -- Load the bundled LuaSnip snippets for Bazel rules (cc_binary, cc_library,
  -- py_binary, cuda_library, genrule, ...). Requires L3MON4D3/LuaSnip; no-op
  -- without it. Set to false if you maintain your own Bazel snippets.
  snippets = true,

  -- bazel executable. nil = auto-detect ("bazel", then "bazelisk").
  bazel = nil, ---@type string?

  -- Filetypes treated as Bazel/Starlark (BUILD, *.bzl, ...).
  filetypes = { "bzl", "bazel", "starlark" },

  -- Workspace root markers, searched upward from the current file.
  root_markers = { "MODULE.bazel", "WORKSPACE.bazel", "WORKSPACE", "WORKSPACE.bzlmod" },

  -- BUILD file names, in priority order.
  build_names = { "BUILD.bazel", "BUILD" },

  -- Buffer-local keymaps in BUILD / *.bzl files. Set a single entry or the
  -- whole table to `false` to disable. Defaults use <localleader> (`\`).
  keys = {
    build = "<localleader>b", -- build the target under the cursor
    test = "<localleader>t", -- test the target under the cursor
    run = "<localleader>r", -- run the target under the cursor (terminal)
    yank = "<localleader>y", -- yank //pkg:target label
    rdeps = "<localleader>R", -- reverse-deps picker
    sources = "<localleader>s", -- open the target's srcs/hdrs
    targets = "<localleader>f", -- workspace target picker
  },

  -- Source filetypes that get the "jump to owning target" / picker maps.
  source_filetypes = { "c", "cpp", "cuda", "python" },
  source_keys = {
    owning_target = "<localleader>b", -- jump to the target owning this file
    targets = "<localleader>f", -- workspace target picker
  },
}

M.defaults = defaults
M.options = vim.deepcopy(defaults) ---@type bazel.Config

---@param opts? bazel.Config
---@return bazel.Config
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return M.options
end

return M
