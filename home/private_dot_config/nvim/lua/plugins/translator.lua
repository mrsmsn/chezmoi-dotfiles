return {
  {
    "voldikss/vim-translator",
    cmd = { "Translate", "TranslateW", "TranslateR", "TranslateX" },
    keys = {
      { "<leader>tt", "<Plug>Translate", mode = "n", desc = "Translate (echo)" },
      { "<leader>tt", "<Plug>TranslateV", mode = "x", desc = "Translate selection (echo)" },
      { "<leader>tw", "<Plug>TranslateW", mode = "n", desc = "Translate (window)" },
      { "<leader>tw", "<Plug>TranslateWV", mode = "x", desc = "Translate selection (window)" },
      { "<leader>tr", "<Plug>TranslateR", mode = "n", desc = "Translate (replace)" },
      { "<leader>tr", "<Plug>TranslateRV", mode = "x", desc = "Translate selection (replace)" },
      { "<leader>tx", "<Plug>TranslateX", mode = "n", desc = "Translate clipboard" },
    },
    init = function()
      vim.g.translator_target_lang = "ja"
      vim.g.translator_source_lang = "auto"
      vim.g.translator_default_engines = { "google", "bing" }
      vim.g.translator_window_type = "popup"
    end,
  },
}
