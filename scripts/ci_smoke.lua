-- Headless smoke test for bazel-nvim (run via `nvim -l scripts/ci_smoke.lua`).
--
-- Adds the repo (and LuaSnip, if cloned to ./.deps/LuaSnip) to the runtimepath,
-- runs setup(), and asserts the core wiring: the plugin loads, :Bazel* commands
-- are created, the health module exposes check(), and the bundled snippets parse.

local function die(msg)
  io.stderr:write("FAIL: " .. msg .. "\n")
  os.exit(1)
end

local root = vim.uv.cwd()
vim.opt.runtimepath:append(root)

-- Use LuaSnip if CI cloned it next to the repo.
local luasnip_dir = root .. "/.deps/LuaSnip"
if vim.uv.fs_stat(luasnip_dir) then
  vim.opt.runtimepath:append(luasnip_dir)
end

-- 1. The plugin loads.
local ok, bazel = pcall(require, "bazel-nvim")
if not ok then
  die("require('bazel-nvim') failed: " .. tostring(bazel))
end

-- 2. setup() must not error (symbols degrade gracefully without a python parser).
local sok, serr = pcall(bazel.setup, {})
if not sok then
  die("setup() errored: " .. tostring(serr))
end

-- 3. :Bazel* user commands are created.
for _, c in ipairs({ "BazelBuild", "BazelTest", "BazelRun", "BazelTargets", "BazelSources" }) do
  if vim.fn.exists(":" .. c) ~= 2 then
    die(c .. " command was not created")
  end
end

-- 4. The health module loads and exposes check().
local hok, health = pcall(require, "bazel-nvim.health")
if not hok or type(health.check) ~= "function" then
  die("bazel-nvim.health.check is missing")
end

-- 5. The bundled snippets file loads; with LuaSnip present it must yield snippets.
local chunk, cerr = loadfile(root .. "/snippets/bzl.lua")
if not chunk then
  die("loadfile snippets/bzl.lua: " .. tostring(cerr))
end
local pok, snips = pcall(chunk)
if not pok then
  die("snippets/bzl.lua errored: " .. tostring(snips))
end
if pcall(require, "luasnip") and #snips == 0 then
  die("LuaSnip is available but no snippets parsed")
end

print(("OK: bazel-nvim loaded, commands + health wired up, %d snippets parsed"):format(#snips))
