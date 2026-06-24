-- LuaSnip snippets for Bazel/Starlark (filetype `bzl`), shipped with bazel-nvim.
--
-- Written with `ls.parser.parse_snippet` so the bodies use familiar VSCode-style
-- `$1` / `${1:default}` / `$0` tabstops (repeated `$1` mirror as you type).
-- Loaded via lua/bazel-nvim/snippets.lua. Disable with `opts.snippets = false`.

local ok, ls = pcall(require, "luasnip")
if not ok then
  return {}
end

local parse = ls.parser.parse_snippet

---@param trig string
---@param desc string
---@param body string
local function snip(trig, desc, body)
  return parse({ trig = trig, desc = desc }, body)
end

return {
  -- ── C / C++ ────────────────────────────────────────────────────────────────
  snip(
    "cc_library",
    "C++ library",
    [[
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "$1",
    srcs = ["$1.cc"],
    hdrs = ["$1.h"],
    visibility = ["//visibility:public"],
    deps = [$0],
)]]
  ),
  snip(
    "cc_binary",
    "C++ binary",
    [[
load("@rules_cc//cc:defs.bzl", "cc_binary")

cc_binary(
    name = "$1",
    srcs = ["$1.cc"],
    visibility = ["//visibility:public"],
    deps = [$0],
)]]
  ),
  snip(
    "cc_test",
    "C++ test",
    [[
load("@rules_cc//cc:defs.bzl", "cc_test")

cc_test(
    name = "$1",
    srcs = ["$1.cc"],
    deps = [
        "@googletest//:gtest_main",$0
    ],
)]]
  ),

  -- ── CUDA ───────────────────────────────────────────────────────────────────
  snip(
    "cuda_library",
    "CUDA library",
    [[
load("@rules_cuda//cuda:defs.bzl", "cuda_library")

cuda_library(
    name = "$1",
    srcs = ["$1.cu"],
    hdrs = ["$1.cuh"],
    visibility = ["//visibility:public"],
    deps = [$0],
)]]
  ),
  snip(
    "cuda_binary",
    "CUDA binary",
    [[
load("@rules_cuda//cuda:defs.bzl", "cuda_binary")

cuda_binary(
    name = "$1",
    srcs = ["$1.cu"],
    visibility = ["//visibility:public"],
    deps = [$0],
)]]
  ),

  -- ── Python ─────────────────────────────────────────────────────────────────
  snip(
    "py_library",
    "Python library",
    [[
load("@rules_python//python:defs.bzl", "py_library")

py_library(
    name = "$1",
    srcs = ["$1.py"],
    visibility = ["//visibility:public"],
    deps = [$0],
)]]
  ),
  snip(
    "py_binary",
    "Python binary",
    [[
load("@rules_python//python:defs.bzl", "py_binary")

py_binary(
    name = "$1",
    srcs = ["$1.py"],
    main = "$1.py",
    visibility = ["//visibility:public"],
    deps = [$0],
)]]
  ),
  snip(
    "py_test",
    "Python test",
    [[
load("@rules_python//python:defs.bzl", "py_test")

py_test(
    name = "$1",
    srcs = ["$1.py"],
    deps = [$0],
)]]
  ),

  -- ── Proto ──────────────────────────────────────────────────────────────────
  snip(
    "proto_library",
    "Proto library",
    [[
load("@rules_proto//proto:defs.bzl", "proto_library")

proto_library(
    name = "$1",
    srcs = ["$1.proto"],
    visibility = ["//visibility:public"],
    deps = [$0],
)]]
  ),
  snip(
    "cc_proto_library",
    "C++ proto library",
    [[
cc_proto_library(
    name = "$1",
    deps = [":$0"],
)]]
  ),

  -- ── Native rules ───────────────────────────────────────────────────────────
  snip(
    "genrule",
    "Generated output rule",
    [[
genrule(
    name = "$1",
    srcs = [$2],
    outs = ["$3"],
    cmd = "$0",
)]]
  ),
  snip(
    "filegroup",
    "Group of files",
    [[
filegroup(
    name = "$1",
    srcs = glob(["$2"]),
    visibility = ["//visibility:public"],
)$0]]
  ),
  snip(
    "alias",
    "Alias to another target",
    [[
alias(
    name = "$1",
    actual = "$2",
    visibility = ["//visibility:public"],
)$0]]
  ),
  snip(
    "test_suite",
    "Test suite",
    [[
test_suite(
    name = "$1",
    tests = [$0],
)]]
  ),
  snip(
    "config_setting",
    "Config setting",
    [[
config_setting(
    name = "$1",
    values = {
        "$2": "$3",
    },
)$0]]
  ),

  -- ── Utilities ──────────────────────────────────────────────────────────────
  snip("load", "Load statement", [[load("$1", "$0")]]),
  snip("exports_files", "Export files", [[exports_files([$0])]]),
  snip(
    "package",
    "Package default settings",
    [[
package(
    default_visibility = ["//visibility:$1"],
)$0]]
  ),
}
