-- Filetype detection for Bazel files that Neovim core doesn't already cover.
--
-- Core already maps: *.bzl, *.bazel (BUILD.bazel/MODULE.bazel/WORKSPACE.bazel),
-- *.BUILD, BUILD, WORKSPACE, WORKSPACE.bzlmod, BUCK -> bzl; *.star/*.sky -> starlark.
-- Here we only add the gaps.
vim.filetype.add({
  extension = {
    bzlproj = "bzl",
  },
  filename = {
    bzlmod = "bzl",
    [".bazelrc"] = "sh",
  },
  pattern = {
    [".*%.bazel%.tpl"] = "bzl", -- BUILD.bazel.tpl, *.bazel.tpl
    [".*%.bzl%.tpl"] = "bzl", -- defs.bzl.tpl
    ["BUILD.*%.tpl"] = "bzl", -- BUILD.something.tpl
    [".*%.bazelrc"] = "sh", -- user.bazelrc, tools.bazelrc, ...
  },
})
