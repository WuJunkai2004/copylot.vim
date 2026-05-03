" plugin name: copylot - Chatbar

if exists('b:did_ftplugin')
    finish
endif
let b:did_ftplugin = 1

" 缓冲区属性设置
setlocal buftype=nofile
setlocal bufhidden=hide
setlocal noswapfile
setlocal nonumber
setlocal norelativenumber
setlocal signcolumn=no
setlocal nomodifiable

nnoremap <buffer><silent> <LeftMouse> <LeftMouse>:call copylot#chat#click()<CR>
