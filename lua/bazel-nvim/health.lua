-- Health check for bazel-nvim: run `:checkhealth bazel-nvim`.
--
-- Verifies the hard requirements (Neovim version, a bazel executable, the Python
-- Tree-sitter parser used for symbols) and reports which optional integrations
-- (snacks.nvim, LuaSnip, blink.cmp, conform + buildifier) are available.

local M = {}

-- Support both the modern (0.10+) and legacy (`report_*`) health APIs.
local h = vim.health
local start = h.start or h.report_start
local ok = h.ok or h.report_ok
local info = h.info or h.report_info
local warn = h.warn or h.report_warn
local err = h.error or h.report_error

---@return string? exe, string? configured
local function bazel_exe()
  local opts = require("bazel-nvim.config").options or {}
  local configured = opts.bazel
  if configured then
    if vim.fn.executable(configured) == 1 then
      return configured, configured
    end
    return nil, configured
  end
  for _, e in ipairs({ "bazel", "bazelisk" }) do
    if vim.fn.executable(e) == 1 then
      return e
    end
  end
end

---@param mod string
---@return boolean
local function has(mod)
  return (pcall(require, mod))
end

function M.check()
  -- ── core requirements ───────────────────────────────────────────────────────
  start("bazel-nvim: core")

  local v = vim.version()
  local vstr = ("%d.%d.%d"):format(v.major, v.minor, v.patch)
  if vim.fn.has("nvim-0.10") == 1 then
    ok("Neovim " .. vstr .. " (>= 0.10)")
  else
    err("Neovim 0.10+ required (uses vim.system, vim.fs.root and in-process LSP); found " .. vstr)
  end

  local exe, configured = bazel_exe()
  if exe then
    ok(("`%s` found (%s)"):format(exe, vim.fn.exepath(exe)))
  elseif configured then
    err(("configured bazel executable `%s` not found on PATH"):format(configured), {
      "Point `opts.bazel` at a valid executable, or install it.",
    })
  else
    err("neither `bazel` nor `bazelisk` found on PATH", {
      "Install Bazel: https://bazel.build/install",
      "Or set `opts.bazel` to the executable path.",
    })
  end

  -- ── document symbols ────────────────────────────────────────────────────────
  start("bazel-nvim: document symbols")
  if pcall(vim.treesitter.language.add, "python") then
    ok("`python` Tree-sitter parser available (Starlark is parsed with it)")
  else
    warn("`python` Tree-sitter parser not found; document symbols are disabled", {
      "Install it with `:TSInstall python`.",
    })
  end

  -- ── optional integrations ───────────────────────────────────────────────────
  start("bazel-nvim: optional integrations")

  if has("snacks") then
    ok("folke/snacks.nvim found (target / rdeps / sources pickers)")
  else
    info("folke/snacks.nvim not found — the target/rdeps/sources pickers are unavailable")
  end

  if has("luasnip") then
    ok("L3MON4D3/LuaSnip found (bundled snippets)")
  else
    info("L3MON4D3/LuaSnip not found — bundled snippets are disabled")
  end

  if has("blink.cmp") then
    ok("saghen/blink.cmp found (label-completion source can be registered)")
  else
    info("saghen/blink.cmp not found — the label-completion source is unused")
  end

  -- ── formatting ──────────────────────────────────────────────────────────────
  start("bazel-nvim: formatting")
  local has_conform = has("conform")
  local has_buildifier = vim.fn.executable("buildifier") == 1
  if has_conform and has_buildifier then
    ok("stevearc/conform.nvim + `buildifier` available (Bazel formatting)")
  else
    if not has_conform then
      info("stevearc/conform.nvim not found — the buildifier integration is unused")
    end
    if not has_buildifier then
      warn("`buildifier` not found on PATH — Bazel formatting will not run", {
        "Install: https://github.com/bazelbuild/buildtools/releases",
      })
    end
  end
end

return M
