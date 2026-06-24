-- Filetype detection for Bazel files that Neovim core doesn't already cover.
--
-- Core already maps: *.bzl, *.bazel (BUILD.bazel/MODULE.bazel/WORKSPACE.bazel),
-- *.BUILD, BUILD, WORKSPACE, WORKSPACE.bzlmod, BUCK -> bzl; *.star/*.sky -> starlark.
-- Here we only add the gaps. (Over-broad patterns such as "*.tpl" or a bare "bzl"
-- substring are intentionally avoided: they'd misdetect unrelated files.)
vim.filetype.add({
  extension = {
    bzlproj = "bzl",
  },
  filename = {
    bzlmod = "bzl",
    workspace = "bzl", -- lowercase variant; core only maps the uppercase WORKSPACE
    [".bazelrc"] = "sh",
  },
  pattern = {
    [".*%.bazel%.tpl"] = "bzl", -- BUILD.bazel.tpl, *.bazel.tpl
    [".*%.bzl%.tpl"] = "bzl", -- defs.bzl.tpl
    ["BUILD.*%.tpl"] = "bzl", -- BUILD.something.tpl
    [".*%.bazelrc"] = "sh", -- user.bazelrc, tools.bazelrc, ...
  },
})
