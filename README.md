# bazel-nvim

Lightweight Bazel/Starlark navigation and actions for Neovim.

It parses `BUILD` / `BUILD.bazel` / `*.bzl` files with the (Starlark-compatible)
**Python Tree-sitter parser** — no extra language server required — and adds:

- **Document symbols** — `cc_binary` / `cc_library` / `py_binary` / `cuda_library`
  / `cc_test` / `genrule` / … targets listed **by name and rule type** in your LSP
  symbol picker (`<leader>ss`), outline and breadcrumbs. Implemented as a tiny
  **in-process LSP server**, so it lights up the editor features you already use.
- **Build / test / run the target under the cursor** — surgical
  `bazel build|test|run //pkg:target` instead of building the whole package.
  Build/test errors go to the quickfix list; `run` opens a terminal.
- **Workspace target picker** — `bazel query //...` piped into a
  [snacks.nvim](https://github.com/folke/snacks.nvim) picker; jump to any target's
  rule in the right `BUILD` file.
- **Yank label** — copy `//package:target` for the rule under the cursor.
- **Source ⇆ BUILD jump** — from a `.cc/.cu/.h/.py` file jump to the target that
  owns it; from a target open its `srcs`/`hdrs`.
- **Reverse-deps picker** — `bazel query "rdeps(//..., //pkg:target)"` to see who
  depends on the target under the cursor.

## Requirements

- Neovim **0.10+** (uses `vim.system`, `vim.fs.root`, in-process LSP).
- The **`python`** Tree-sitter parser (for symbols / parsing): `:TSInstall python`.
- **`bazel`** (or `bazelisk`) on `PATH` — for build/test/run/query/navigation.
- **[folke/snacks.nvim](https://github.com/folke/snacks.nvim)** — for the target /
  rdeps / sources pickers (optional; the rest works without it).
- Plays nicely with the [`starpls`](https://github.com/withered-magic/starpls)
  language server: its weaker document symbols are suppressed to avoid duplicates.

## Installation

### lazy.nvim

```lua
{
  "sibi-venti/bazel-nvim",
  dependencies = { "folke/snacks.nvim" },
  ft = { "bzl", "bazel", "starlark", "c", "cpp", "cuda", "python" },
  opts = {},
}
```

`opts = {}` is enough — lazy.nvim auto-calls `require("bazel-nvim").setup(opts)`.

### Local development

```lua
{
  dir = "~/.config/bazel-nvim",
  dependencies = { "folke/snacks.nvim" },
  ft = { "bzl", "bazel", "starlark", "c", "cpp", "cuda", "python" },
  opts = {},
}
```

## Configuration

These are the defaults; pass overrides via `opts`.

```lua
{
  -- Document symbols (in-process LSP). cc_binary/cc_library/... in <leader>ss.
  symbols = true,
  -- Suppress starpls' weaker document symbols to avoid duplicate entries.
  suppress_starpls_symbols = true,
  -- Create the :Bazel* user commands.
  commands = true,
  -- bazel executable. nil = auto-detect ("bazel", then "bazelisk").
  bazel = nil,

  filetypes = { "bzl", "bazel", "starlark" },
  root_markers = { "MODULE.bazel", "WORKSPACE.bazel", "WORKSPACE", "WORKSPACE.bzlmod" },
  build_names = { "BUILD.bazel", "BUILD" },

  -- Buffer-local keymaps in BUILD / *.bzl files (<localleader> = `\` by default).
  -- Set any entry or the whole table to `false` to disable.
  keys = {
    build   = "<localleader>b",
    test    = "<localleader>t",
    run     = "<localleader>r",
    yank    = "<localleader>y",
    rdeps   = "<localleader>R",
    sources = "<localleader>s",
    targets = "<localleader>f",
  },

  -- Keymaps in source files (C/C++/CUDA/Python).
  source_filetypes = { "c", "cpp", "cuda", "python" },
  source_keys = {
    owning_target = "<localleader>b",
    targets       = "<localleader>f",
  },
}
```

## Commands

| Command         | Description                                            |
| --------------- | ------------------------------------------------------ |
| `:BazelBuild`   | Build the target under the cursor                      |
| `:BazelTest`    | Test the target under the cursor                       |
| `:BazelRun`     | Run the target under the cursor (terminal)             |
| `:BazelLabel`   | Yank the `//pkg:target` label under the cursor         |
| `:BazelTargets` | Pick any target in the workspace and jump to it        |
| `:BazelRdeps`   | Reverse-deps picker for the target under the cursor    |
| `:BazelTarget`  | Jump to the target that owns the current source file   |
| `:BazelSources` | Open the `srcs`/`hdrs` of the target under the cursor  |

## Default keymaps

In `BUILD` / `*.bzl` files (`<localleader>` = `\`):

| Key  | Action                                |
| ---- | ------------------------------------- |
| `\b` | Build target under cursor             |
| `\t` | Test target under cursor              |
| `\r` | Run target under cursor               |
| `\y` | Yank `//pkg:target` label             |
| `\R` | Reverse-deps picker                   |
| `\s` | Open the target's `srcs`/`hdrs`       |
| `\f` | Workspace target picker               |

In `.cc/.cu/.h/.py` files:

| Key  | Action                            |
| ---- | --------------------------------- |
| `\b` | Jump to the target owning the file|
| `\f` | Workspace target picker           |

## Lua API

Everything is available on `require("bazel-nvim")` for custom keymaps:

```lua
local bazel = require("bazel-nvim")
bazel.action("build" | "test" | "run")
bazel.yank_label()
bazel.pick_targets()
bazel.pick_rdeps()
bazel.open_sources()
bazel.goto_owning_target()
bazel.goto_label("//pkg:target")
bazel.cursor_target()              -- { label, name, rule, root } | nil, err
bazel.query("//...", root, cb)     -- async bazel query
bazel.document_symbols(bufnr)      -- LSP DocumentSymbol[]
```

## How the symbols work

`BUILD` files have no language server that lists targets usefully. `bazel-nvim`
starts an in-process LSP server (`vim.lsp.start` with a Lua `cmd`) that answers
`textDocument/documentSymbol` by parsing the buffer with the Python Tree-sitter
parser and emitting one symbol per rule call that has a `name = "..."` argument,
using the rule name as the `detail` and a fitting `SymbolKind` for the icon. Any
`starpls` document symbols are suppressed so targets aren't listed twice.

## License

MIT
