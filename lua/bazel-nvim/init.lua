-- bazel-nvim: Bazel/Starlark navigation & actions for Neovim.
-- See README.md. Entry point: require("bazel-nvim").setup(opts).

local M = {}

-- ── public API (handy for custom keymaps) ─────────────────────────────────────

---@param kind "build"|"test"|"run"
function M.action(kind)
  return require("bazel-nvim.tools").action(kind)
end
function M.build()
  return M.action("build")
end
function M.test()
  return M.action("test")
end
function M.run()
  return M.action("run")
end
function M.build_package()
  return require("bazel-nvim.tools").build_package()
end
function M.yank_label()
  return require("bazel-nvim.tools").yank_label()
end
function M.pick_targets()
  return require("bazel-nvim.tools").pick_targets()
end
function M.pick_rdeps()
  return require("bazel-nvim.tools").pick_rdeps()
end
function M.open_sources()
  return require("bazel-nvim.tools").open_sources()
end
function M.goto_owning_target()
  return require("bazel-nvim.tools").goto_owning_target()
end
---@param label string
---@param root? string
function M.goto_label(label, root)
  return require("bazel-nvim.tools").goto_label(label, root)
end
function M.cursor_target()
  return require("bazel-nvim.tools").cursor_target()
end
---@param expr string
---@param root string
---@param cb fun(labels?: string[], err?: string)
function M.query(expr, root, cb)
  return require("bazel-nvim.tools").query(expr, root, cb)
end
--- Document symbols for a buffer (LSP DocumentSymbol[]).
function M.document_symbols(bufnr)
  return require("bazel-nvim.symbols").document_symbols(bufnr)
end

-- ── keymap wiring ─────────────────────────────────────────────────────────────

-- key-config name -> { handler, description }
local BUILD_ACTIONS = {
  build = { M.build, "Bazel: build target under cursor" },
  build_package = { M.build_package, "Bazel: build whole package (//pkg:all)" },
  test = { M.test, "Bazel: test target under cursor" },
  run = { M.run, "Bazel: run target under cursor" },
  yank = { M.yank_label, "Bazel: yank //pkg:target label" },
  rdeps = { M.pick_rdeps, "Bazel: reverse deps of target" },
  sources = { M.open_sources, "Bazel: open srcs/hdrs of target" },
  targets = { M.pick_targets, "Bazel: find target in workspace" },
}

local SOURCE_ACTIONS = {
  owning_target = { M.goto_owning_target, "Bazel: jump to owning target" },
  targets = { M.pick_targets, "Bazel: find target in workspace" },
}

---@param buf integer
---@param keys table<string, string|false>
---@param actions table<string, table>
local function apply_keys(buf, keys, actions)
  for name, lhs in pairs(keys or {}) do
    local spec = actions[name]
    if lhs and spec then
      vim.keymap.set("n", lhs, spec[1], { buffer = buf, silent = true, desc = spec[2] })
    end
  end
end

---@param opts? bazel.Config
function M.setup(opts)
  local config = require("bazel-nvim.config").setup(opts)

  if config.symbols then
    require("bazel-nvim.symbols").setup(config)
  end

  if config.commands then
    require("bazel-nvim.tools").create_commands()
  end

  if config.snippets then
    require("bazel-nvim.snippets").setup(config)
  end

  local group = vim.api.nvim_create_augroup("bazel-nvim-keys", { clear = true })
  if config.keys then
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = config.filetypes,
      callback = function(ev)
        apply_keys(ev.buf, config.keys, BUILD_ACTIONS)
      end,
    })
  end
  if config.source_keys then
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = config.source_filetypes,
      callback = function(ev)
        apply_keys(ev.buf, config.source_keys, SOURCE_ACTIONS)
      end,
    })
  end

  -- Apply keymaps to buffers already open when the plugin loads.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.bo[buf].filetype
      if config.keys and vim.tbl_contains(config.filetypes, ft) then
        apply_keys(buf, config.keys, BUILD_ACTIONS)
      elseif config.source_keys and vim.tbl_contains(config.source_filetypes, ft) then
        apply_keys(buf, config.source_keys, SOURCE_ACTIONS)
      end
    end
  end
end

return M
