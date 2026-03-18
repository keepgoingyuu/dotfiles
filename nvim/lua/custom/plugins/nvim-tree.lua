-- plugins/nvim-tree.lua
return {
  'nvim-tree/nvim-tree.lua',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require('nvim-tree').setup({
      -- 自動同步當前檔案位置
      update_focused_file = {
        enable = true,          -- 啟用自動更新
        update_cwd = false,     -- 不更新工作目錄
        update_root = false,    -- 不更新根目錄
        ignore_list = {},       -- 忽略的檔案列表
      },
      
      -- 其他有用的設定
      view = {
        width = 30,             -- 側邊欄寬度
        side = 'left',          -- 側邊欄位置
      },
      
      -- Git 整合
      git = {
        enable = true,
        ignore = false,
      },
      
      -- 檔案過濾
      filters = {
        dotfiles = false,       -- 顯示隱藏檔案
        custom = { '.git', 'node_modules', '.cache' },
      },
      
      -- 診斷標記
      diagnostics = {
        enable = true,
        show_on_dirs = true,
        icons = {
          hint = "",
          info = "",
          warning = "",
          error = "",
        },
      },
      
      -- 渲染器設定
      renderer = {
        group_empty = true,     -- 合併空資料夾
        highlight_git = true,   -- 高亮 git 狀態
        icons = {
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
            git = true,
          },
        },
      },
    })
    
    -- 快捷鍵設定
    vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { desc = "Toggle Nvim Tree", noremap = true, silent = true })
    vim.keymap.set('n', '<leader>nf', ':NvimTreeFindFile<CR>', { desc = "Find current file in tree", noremap = true, silent = true })
    vim.keymap.set('n', '<leader>nc', ':NvimTreeCollapse<CR>', { desc = "Collapse Nvim Tree", noremap = true, silent = true })
    
    -- 自動開啟 NvimTree 當 Neovim 啟動時
    local function open_nvim_tree(data)
      -- buffer is a directory
      local directory = vim.fn.isdirectory(data.file) == 1
      
      if not directory then
        return
      end
      
      -- change to the directory
      vim.cmd.cd(data.file)
      
      -- open the tree
      require("nvim-tree.api").tree.open()
    end
    
    vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
  end,
}

