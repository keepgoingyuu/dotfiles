-- Flash.nvim - 快速跳轉和搜尋
return {
  "folke/flash.nvim",
  event = "VeryLazy",
  opts = {
    -- 標籤顯示設定
    labels = "asdfghjklqwertyuiopzxcvbnm",  -- 使用的標籤字母
    search = {
      -- 搜尋設定
      multi_window = true,    -- 可以跨視窗跳轉
      forward = true,         -- 預設向前搜尋
      wrap = true,            -- 循環搜尋
      mode = "exact",         -- exact, search, fuzzy
    },
    jump = {
      -- 跳轉設定
      jumplist = true,        -- 加入跳轉歷史
      pos = "start",          -- 跳到匹配的開始位置
      autojump = false,       -- 只有一個匹配時不自動跳轉（避免誤跳）
    },
    label = {
      -- 標籤樣式
      uppercase = false,      -- 不使用大寫字母
      after = true,          -- 標籤顯示在匹配文字後面
      before = false,         -- 標籤不顯示在前面
      style = "overlay",      -- overlay, inline, eol
      reuse = "lowercase",    -- 優先重複使用小寫字母
      distance = true,        -- 優先使用距離近的標籤
    },
    highlight = {
      -- 高亮設定
      backdrop = true,        -- 暗化背景
      matches = true,         -- 高亮匹配
      labels = true,          -- 高亮標籤
      priority = 5000,        -- 高亮優先級
    },
    modes = {
      -- 模式設定
      search = {
        enabled = true,       -- 啟用搜尋模式
        highlight = { backdrop = false },
      },
      char = {
        enabled = true,
        keys = { "f", "F", "t", "T", ";", "," },  -- 增強 f/t 動作
        multi_line = true,    -- 可以跨行
        autohide = false,     -- 不自動隱藏
        jump_labels = true,   -- 使用跳轉標籤
      },
      treesitter = {
        labels = "abcdefghijklmnopqrstuvwxyz",
        jump = { pos = "range" },
        highlight = {
          backdrop = false,
          matches = false,
        },
      },
    },
  },
  keys = {
    -- 主要功能：按 s 開始跳轉
    {
      "s",
      mode = { "n", "x", "o" },
      function()
        require("flash").jump()
      end,
      desc = "Flash Jump",
    },
    
    -- 按 S 開始 Treesitter 選擇（跳到程式碼結構）
    {
      "S",
      mode = { "n", "x", "o" },
      function()
        require("flash").treesitter()
      end,
      desc = "Flash Treesitter",
    },
    
    -- 在 operator-pending 模式使用 r
    {
      "r",
      mode = "o",
      function()
        require("flash").remote()
      end,
      desc = "Remote Flash",
    },
    
    -- 在搜尋模式中切換 Flash
    {
      "<c-s>",
      mode = { "c" },
      function()
        require("flash").toggle()
      end,
      desc = "Toggle Flash Search",
    },
  },
}