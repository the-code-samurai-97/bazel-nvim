-- blink.cmp completion source for Bazel labels in BUILD / *.bzl files.
--
-- Completes:
--   "//pkg/pa|        -> sub-package directories under the workspace
--   "//pkg:ta|        -> rule targets in //pkg   (bazel query kind('rule', ...))
--   ":ta|             -> rule targets in the current package
--   "src/fi|          -> files/dirs relative to the current package
--
-- Registered from your config via:
--   sources.providers.bazel = { name = "Bazel", module = "bazel-nvim.blink" }

local KIND = vim.lsp.protocol.CompletionItemKind
local IGNORE_DIRS = {
  [".git"] = true,
  ["bazel-bin"] = true,
  ["bazel-out"] = true,
  ["bazel-testlogs"] = true,
}

-- Short-lived cache for `bazel query` results, keyed by "root\0pkg".
local query_cache = {} ---@type table<string, { time:number, labels:string[] }>
local QUERY_TTL = 5 -- seconds

---@return string?
local function bazel_exe()
  local configured = require("bazel-nvim.config").options.bazel
  if configured then
    return vim.fn.executable(configured) == 1 and configured or nil
  end
  for _, e in ipairs({ "bazel", "bazelisk" }) do
    if vim.fn.executable(e) == 1 then
      return e
    end
  end
end

---@param root string
---@param dir string
---@return string
local function package_of(root, dir)
  if dir == root then
    return ""
  end
  return (dir:sub(#root + 2):gsub("\\", "/"))
end

-- Scan a directory, calling `fn(name, type)` for each non-hidden entry.
---@param dir string
---@param fn fun(name:string, typ:string)
local function scandir(dir, fn)
  local fs = vim.uv.fs_scandir(dir)
  if not fs then
    return
  end
  while true do
    local name, typ = vim.uv.fs_scandir_next(fs)
    if not name then
      break
    end
    if name:sub(1, 1) ~= "." then
      fn(name, typ)
    end
  end
end

-- Async `bazel query kind('rule', '//pkg:*')`, returning target names via cb.
---@param root string
---@param pkg string
---@param cb fun(names: string[])
local function query_targets(root, pkg, cb)
  local exe = bazel_exe()
  if not root or not exe then
    return cb({})
  end
  local key = root .. "\0" .. pkg
  local cached = query_cache[key]
  if cached and (vim.uv.now() / 1000 - cached.time) < QUERY_TTL then
    return cb(cached.labels)
  end
  vim.system({
    exe,
    "query",
    ("kind('rule', '//%s:*')"):format(pkg),
    "--output=label",
    "--keep_going",
    "--noshow_progress",
  }, { cwd = root, text = true }, function(res)
    local names = {}
    for line in (res.stdout or ""):gmatch("[^\r\n]+") do
      local name = line:match(":([^:]+)$")
      if name then
        names[#names + 1] = name
      end
    end
    query_cache[key] = { time = vim.uv.now() / 1000, labels = names }
    cb(names)
  end)
end

local source = {}

function source.new(opts)
  return setmetatable({ opts = opts or {} }, { __index = source })
end

function source:enabled()
  return vim.bo[vim.api.nvim_get_current_buf()].filetype == "bzl"
end

function source:get_trigger_characters()
  return { '"', "'", "/", ":" }
end

---@param context blink.cmp.Context
---@param on_items fun(items: table[], is_cached: boolean)
function source:get_completions(context, on_items)
  local row = context.cursor[1] - 1
  local col = context.cursor[2] -- 0-indexed byte column
  local before = context.line:sub(1, col)

  -- Must be inside an unterminated string literal.
  local qpos
  for i = #before, 1, -1 do
    local c = before:sub(i, i)
    if c == '"' or c == "'" then
      qpos = i
      break
    end
  end
  if not qpos then
    return on_items({}, false)
  end
  local label = before:sub(qpos + 1) -- text inside the string, up to the cursor
  if label:find("[\"']") then
    return on_items({}, false) -- string already closed before the cursor
  end

  -- Replacement range: from the start of the current segment (after the last
  -- `/`, `:` or the opening quote) to the cursor.
  local seg = qpos -- 0-indexed start = char right after the opening quote
  for i = #before, qpos + 1, -1 do
    local c = before:sub(i, i)
    if c == "/" or c == ":" then
      seg = i
      break
    end
  end
  local range = { start = { line = row, character = seg }, ["end"] = { line = row, character = col } }

  local bufnr = context.bufnr
  local root = require("bazel-nvim.tools").root(bufnr)

  ---@param entries { label:string, kind:integer, newText:string }[]
  local function emit(entries)
    local items = {}
    for _, e in ipairs(entries) do
      items[#items + 1] = {
        label = e.label,
        kind = e.kind,
        textEdit = { range = vim.deepcopy(range), newText = e.newText },
      }
    end
    on_items(items, false)
  end

  if label:sub(1, 2) == "//" then
    local body = label:sub(3)
    local colon = body:find(":")
    if colon then
      -- //pkg:target  -> rule targets in //pkg
      local pkg = body:sub(1, colon - 1)
      query_targets(root, pkg, function(names)
        local entries = {}
        for _, n in ipairs(names) do
          entries[#entries + 1] = { label = n, kind = KIND.Field, newText = n }
        end
        vim.schedule(function()
          emit(entries)
        end)
      end)
    else
      -- //pkg/path  -> sub-package directories
      if not root then
        return on_items({}, false)
      end
      local sub = body:match("^(.*)/[^/]*$") or ""
      local dir = root .. (sub ~= "" and ("/" .. sub) or "")
      local entries = {}
      scandir(dir, function(name, typ)
        if typ == "directory" and not IGNORE_DIRS[name] then
          entries[#entries + 1] = { label = name .. "/", kind = KIND.Folder, newText = name }
        end
      end)
      emit(entries)
    end
  elseif label:sub(1, 1) == ":" then
    -- :target  -> rule targets in the current package
    local pkg = root and package_of(root, vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))) or ""
    query_targets(root, pkg, function(names)
      local entries = {}
      for _, n in ipairs(names) do
        entries[#entries + 1] = { label = n, kind = KIND.Field, newText = n }
      end
      vim.schedule(function()
        emit(entries)
      end)
    end)
  else
    -- relative file path within the current package
    local bufdir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
    local sub = label:match("^(.*)/[^/]*$") or ""
    local dir = bufdir .. (sub ~= "" and ("/" .. sub) or "")
    local entries = {}
    scandir(dir, function(name, typ)
      if not IGNORE_DIRS[name] then
        local is_dir = typ == "directory"
        entries[#entries + 1] = {
          label = is_dir and (name .. "/") or name,
          kind = is_dir and KIND.Folder or KIND.File,
          newText = name,
        }
      end
    end)
    emit(entries)
  end
end

return source
