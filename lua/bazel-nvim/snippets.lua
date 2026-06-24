-- Loads the plugin's LuaSnip snippets (snippets/<ft>.lua) when LuaSnip is
-- available. No-op if LuaSnip isn't installed.

local M = {}

-- Absolute path to the plugin's top-level `snippets/` directory.
local function snippets_dir()
  -- this file: <root>/lua/bazel-nvim/snippets.lua  ->  <root>/snippets
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(source, ":h:h:h") .. "/snippets"
end

---@param config bazel.Config
function M.setup(config)
  local ok, from_lua = pcall(require, "luasnip.loaders.from_lua")
  if not ok then
    return -- LuaSnip not installed; snippets are optional.
  end

  from_lua.lazy_load({ paths = { snippets_dir() } })

  -- Snippets live in snippets/bzl.lua; reuse them for related filetypes.
  local ls = require("luasnip")
  for _, ft in ipairs(config.filetypes) do
    if ft ~= "bzl" then
      ls.filetype_extend(ft, { "bzl" })
    end
  end
end

return M
