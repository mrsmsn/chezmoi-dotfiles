-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- ターミナル側の背景を透過させるため、colorscheme 適用後に主要ハイライトの bg を NONE に戻す。
local function clear_bg()
  for _, group in ipairs({
    "Normal",
    "NormalNC",
    "NormalFloat",
    "FloatBorder",
    "SignColumn",
    "EndOfBuffer",
    "VertSplit",
    "WinSeparator",
    "StatusLine",
    "StatusLineNC",
    "TabLine",
    "TabLineFill",
    "TelescopeNormal",
    "TelescopeBorder",
    "NeoTreeNormal",
    "NeoTreeNormalNC",
    "NeoTreeEndOfBuffer",
  }) do
    vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("transparent_bg", { clear = true }),
  callback = clear_bg,
})

-- VeryLazy 時点では colorscheme が既に適用済みなので一度直接呼ぶ。
clear_bg()

-- markdown は日本語主体で、英語 spell check が全語を誤検出して邪魔になるため OFF にする。
-- LazyVim の lazyvim_wrap_spell より後に登録されるので上書きできる (wrap は維持)。
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("md_no_spell", { clear = true }),
  pattern = "markdown",
  callback = function()
    vim.opt_local.spell = false
  end,
})
