-- Bazel/Starlark document symbols for `<leader>ss` (and outline, breadcrumbs).
--
-- BUILD / BUILD.bazel / *.bzl files have no useful document symbols out of the
-- box (the `starpls` server reports bare target names with no rule type). This
-- module runs a tiny *in-process* LSP server advertising `documentSymbolProvider`
-- that parses the buffer with the (Starlark-compatible) Python Tree-sitter parser
-- and reports each rule call by name together with its rule type, e.g.
--
--     cc_binary(name = "main_app", ...)    ->  [Function] main_app    cc_binary
--     cc_library(name = "math_utils", ...) ->  [Class]    math_utils  cc_library
--     py_binary / cuda_library / cc_test / genrule / ...
--
-- For .bzl files it also reports top-level `def` functions and assignments.
-- Because it advertises `documentSymbol`, editor features that depend on it
-- (the symbol picker, outline, navic breadcrumbs) light up automatically.

local M = {}

local SymbolKind = vim.lsp.protocol.SymbolKind

-- Pick an LSP SymbolKind for a rule. These kinds are all part of LazyVim's
-- default symbol `kind_filter`, so targets are never filtered out, and they give
-- visually distinct icons.
---@param rule string e.g. "cc_binary", "native.cc_library", "py_test"
---@return integer
local function rule_to_kind(rule)
  local short = rule:match("[%w_]+$") or rule
  if short:match("_test$") then
    return SymbolKind.Method
  elseif short:match("_binary$") then
    return SymbolKind.Function
  elseif short:match("library$") or short:match("_proto$") or short:match("module$") then
    return SymbolKind.Class
  end
  return SymbolKind.Struct
end

-- Literal value of a Python `string` node without quotes/prefix. Non-literal
-- expressions fall back to their raw source text.
---@param node TSNode
---@param src string
---@return string
local function string_value(node, src)
  if node:type() == "string" then
    for i = 0, node:named_child_count() - 1 do
      local child = node:named_child(i)
      if child:type() == "string_content" then
        return vim.treesitter.get_node_text(child, src)
      end
    end
    return ""
  end
  return vim.treesitter.get_node_text(node, src)
end

---@param node TSNode
---@return lsp.Range
local function range_of(node)
  local sr, sc, er, ec = node:range()
  return { start = { line = sr, character = sc }, ["end"] = { line = er, character = ec } }
end

-- Find the `name = "..."` value node in a call's argument_list.
---@param args TSNode argument_list
---@param src string
---@return TSNode?
local function find_name_arg(args, src)
  for i = 0, args:named_child_count() - 1 do
    local arg = args:named_child(i)
    if arg:type() == "keyword_argument" then
      local key = arg:field("name")[1]
      local val = arg:field("value")[1]
      if key and val and vim.treesitter.get_node_text(key, src) == "name" then
        return val
      end
    end
  end
end

-- Turn one top-level statement into a DocumentSymbol (or nil).
---@param stmt TSNode
---@param src string
---@return lsp.DocumentSymbol?
local function statement_symbol(stmt, src)
  local t = stmt:type()

  if t == "function_definition" then
    local name = stmt:field("name")[1]
    if name then
      return {
        name = vim.treesitter.get_node_text(name, src),
        detail = "def",
        kind = SymbolKind.Function,
        range = range_of(stmt),
        selectionRange = range_of(name),
      }
    end
    return nil
  end

  local inner = t == "expression_statement" and stmt:named_child(0) or stmt
  if not inner then
    return nil
  end

  if inner:type() == "call" then
    local func = inner:field("function")[1]
    local args = inner:field("arguments")[1]
    if not (func and args and args:type() == "argument_list") then
      return nil
    end
    local name_node = find_name_arg(args, src)
    if not name_node then
      return nil -- load(), package(), licenses(), ... — not a target
    end
    local rule = vim.treesitter.get_node_text(func, src)
    return {
      name = string_value(name_node, src),
      detail = rule,
      kind = rule_to_kind(rule),
      range = range_of(inner),
      selectionRange = range_of(func),
    }
  end

  if inner:type() == "assignment" then
    local left = inner:field("left")[1]
    if left and left:type() == "identifier" then
      local name = vim.treesitter.get_node_text(left, src)
      return {
        name = name,
        detail = "",
        kind = name:match("^_?%u[%u%d_]*$") and SymbolKind.Constant or SymbolKind.Variable,
        range = range_of(stmt),
        selectionRange = range_of(left),
      }
    end
  end

  return nil
end

---@param bufnr integer
---@return TSNode?
local function parse_root(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  local src = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  -- Starlark is syntactically a subset of Python; reuse the Python parser so we
  -- don't depend on a separately-installed `starlark` parser.
  local ok, parser = pcall(vim.treesitter.get_string_parser, src, "python")
  if not ok or not parser then
    return nil
  end
  return parser:parse()[1]:root(), src
end

--- LSP DocumentSymbol[] for a buffer's rule calls, defs and assignments.
---@param bufnr integer
---@return lsp.DocumentSymbol[]
function M.document_symbols(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local root, src = parse_root(bufnr)
  if not root then
    return {}
  end
  local symbols = {} ---@type lsp.DocumentSymbol[]
  for i = 0, root:named_child_count() - 1 do
    local sym = statement_symbol(root:named_child(i), src)
    if sym then
      symbols[#symbols + 1] = sym
    end
  end
  return symbols
end

---@class BazelTarget
---@field name string
---@field rule string
---@field start_row integer 0-indexed
---@field end_row integer 0-indexed

--- Flat list of rule targets (top-level calls with a `name = "..."`).
---@param bufnr integer
---@return BazelTarget[]
function M.targets(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local root, src = parse_root(bufnr)
  if not root then
    return {}
  end
  local targets = {} ---@type BazelTarget[]
  for i = 0, root:named_child_count() - 1 do
    local stmt = root:named_child(i)
    local inner = stmt:type() == "expression_statement" and stmt:named_child(0) or stmt
    if inner and inner:type() == "call" then
      local func = inner:field("function")[1]
      local args = inner:field("arguments")[1]
      if func and args and args:type() == "argument_list" then
        local name_node = find_name_arg(args, src)
        if name_node then
          local sr, _, er = inner:range()
          targets[#targets + 1] = {
            name = string_value(name_node, src),
            rule = vim.treesitter.get_node_text(func, src),
            start_row = sr,
            end_row = er,
          }
        end
      end
    end
  end
  return targets
end

--- The rule target whose block contains `row` (0-indexed), or nil.
---@param bufnr integer
---@param row integer
---@return BazelTarget?
function M.target_at(bufnr, row)
  local match ---@type BazelTarget?
  for _, t in ipairs(M.targets(bufnr)) do
    if t.start_row <= row and row <= t.end_row then
      match = t
    end
  end
  return match
end

-- ── in-process LSP server ────────────────────────────────────────────────────

---@param dispatchers vim.lsp.rpc.Dispatchers
---@return vim.lsp.rpc.PublicClient
local function make_server(dispatchers)
  local closing = false
  local id = 0
  return {
    request = function(method, params, callback, notify_callback)
      id = id + 1
      local function reply(result)
        if callback then
          vim.schedule(function()
            callback(nil, result)
          end)
        end
      end
      if method == "initialize" then
        reply({
          capabilities = {
            documentSymbolProvider = true,
            textDocumentSync = { openClose = true, change = 1 },
          },
          serverInfo = { name = "bazel-symbols", version = "1.0.0" },
        })
      elseif method == "textDocument/documentSymbol" then
        vim.schedule(function()
          local buf = vim.uri_to_bufnr(params.textDocument.uri)
          local ok, result = pcall(M.document_symbols, buf)
          if callback then
            callback(nil, ok and result or {})
          end
        end)
      else
        reply(nil)
      end
      if notify_callback then
        vim.schedule(function()
          notify_callback(id)
        end)
      end
      return true, id
    end,
    notify = function(method)
      if method == "exit" then
        closing = true
        if dispatchers and dispatchers.on_exit then
          dispatchers.on_exit(0, 15)
        end
      end
      return true
    end,
    is_closing = function()
      return closing
    end,
    terminate = function()
      closing = true
    end,
  }
end

---@param config bazel.Config
function M.setup(config)
  -- We rely on the Python Tree-sitter parser; bail quietly if it's missing.
  if not pcall(vim.treesitter.language.add, "python") then
    vim.schedule(function()
      vim.notify(
        "[bazel-nvim] Python Tree-sitter parser not found; symbols disabled.\nInstall it with `:TSInstall python`.",
        vim.log.levels.WARN
      )
    end)
    return
  end

  local fts = {} ---@type table<string, boolean>
  for _, ft in ipairs(config.filetypes) do
    fts[ft] = true
  end

  local function attach(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) or not fts[vim.bo[bufnr].filetype] then
      return
    end
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root = vim.fs.root(bufnr, config.root_markers) or (fname ~= "" and vim.fs.dirname(fname)) or vim.uv.cwd()
    vim.lsp.start({
      name = "bazel-symbols",
      cmd = make_server,
      root_dir = root,
      -- Tree-sitter reports byte columns; treat them as bytes so jumps land
      -- correctly for non-ASCII target names too.
      offset_encoding = "utf-8",
    }, { bufnr = bufnr })
  end

  local group = vim.api.nvim_create_augroup("bazel-nvim-symbols", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = config.filetypes,
    callback = function(args)
      attach(args.buf)
    end,
  })

  if config.suppress_starpls_symbols then
    vim.api.nvim_create_autocmd("LspAttach", {
      group = group,
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == "starpls" then
          client.server_capabilities.documentSymbolProvider = false
        end
      end,
    })
    for _, client in ipairs(vim.lsp.get_clients({ name = "starpls" })) do
      client.server_capabilities.documentSymbolProvider = false
    end
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      attach(bufnr)
    end
  end
end

return M
