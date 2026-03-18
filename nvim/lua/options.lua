-- 針對不同語言設定縮排
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'python' },
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = true
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'go' },
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = false -- Go 通常使用 tab 字元
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'javascript', 'typescript', 'html', 'css' },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.expandtab = true -- 前端語言通常使用空格
  end,
})

vim.keymap.set('i', 'jk', '<Esc>')
vim.keymap.set('n', '<leader>-', ':split<CR>', { desc = 'Split window horizontally', noremap = true, silent = true })
vim.keymap.set('n', '<leader>|', ':vsplit<CR>', { desc = 'Split window vertically', noremap = true, silent = true })
