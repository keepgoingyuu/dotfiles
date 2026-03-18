-- Oil.nvim - 像編輯文字一樣管理檔案
return {
  'stevearc/oil.nvim',
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("oil").setup({
      -- 預設選項
      default_file_explorer = true,  -- 取代 netrw 成為預設檔案瀏覽器
      
      -- 欄位顯示
      columns = {
        "icon",
        -- "permissions",
        -- "size",
        -- "mtime",
      },
      
      -- 緩衝區選項
      buf_options = {
        buflisted = false,
        bufhidden = "hide",
      },
      
      -- 視窗選項
      win_options = {
        wrap = false,
        signcolumn = "no",
        cursorcolumn = false,
        foldcolumn = "0",
        spell = false,
        list = false,
        conceallevel = 3,
        concealcursor = "nvic",
      },
      
      -- 刪除到垃圾桶而不是永久刪除
      delete_to_trash = false,
      
      -- 跳過確認某些操作
      skip_confirm_for_simple_edits = false,
      
      -- 選擇新檔案或目錄時的提示
      prompt_save_on_select_new_entry = true,
      
      -- Oil 會自動在當前目錄開啟（當開啟目錄時）
      cleanup_delay_ms = 2000,
      
      -- 按鍵映射
      keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<C-s>"] = "actions.select_vsplit",
        ["<C-h>"] = "actions.select_split",
        ["<C-t>"] = "actions.select_tab",
        ["<C-p>"] = "actions.preview",
        ["<C-c>"] = "actions.close",
        ["<C-l>"] = "actions.refresh",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["~"] = "actions.tcd",
        ["gs"] = "actions.change_sort",
        ["gx"] = "actions.open_external",
        ["g."] = "actions.toggle_hidden",
        ["g\\"] = "actions.toggle_trash",
      },
      
      -- 使用預設按鍵映射
      use_default_keymaps = true,
      
      -- 視圖選項
      view_options = {
        -- 顯示隱藏檔案
        show_hidden = true,
        
        -- 這是一個函數，定義什麼檔案應該被隱藏
        is_hidden_file = function(name, bufnr)
          return vim.startswith(name, ".")
        end,
        
        -- 這是一個函數，定義檔案應該總是被隱藏
        is_always_hidden = function(name, bufnr)
          return name == ".." or name == ".git"
        end,
        
        -- 排序
        sort = {
          -- 排序可以是 "name", "size", "type", "mtime"
          { "type", "asc" },
          { "name", "asc" },
        },
      },
      
      -- 浮動視窗配置
      float = {
        -- 填充視窗周圍
        padding = 2,
        max_width = 0,
        max_height = 0,
        border = "rounded",
        win_options = {
          winblend = 0,
        },
        
        -- 這是預覽視窗在右邊的範例配置：
        -- preview_split = "right",
      },
      
      -- 預覽配置
      preview = {
        max_width = 0.9,
        min_width = { 40, 0.4 },
        max_height = 0.9,
        min_height = { 5, 0.1 },
        border = "rounded",
        win_options = {
          winblend = 0,
        },
      },
      
      -- 進度顯示配置
      progress = {
        max_width = 0.9,
        min_width = { 40, 0.4 },
        max_height = { 10, 0.9 },
        min_height = { 5, 0.1 },
        border = "rounded",
        minimized_border = "none",
        win_options = {
          winblend = 0,
        },
      },
    })
    
    -- 設定快捷鍵
    vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
    vim.keymap.set("n", "<leader>o", function()
      require("oil").open_float()
    end, { desc = "Open Oil in floating window" })
    vim.keymap.set("n", "<leader>O", "<CMD>Oil .<CR>", { desc = "Open Oil in current directory" })
  end,
}