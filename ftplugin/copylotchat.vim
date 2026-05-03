" plugin name: copylot - Chatbar

if exists('b:current_syntax')
    finish
endif

runtime! syntax/markdown.vim
unlet b:current_syntax

" 缓冲区属性设置
setlocal buftype=nofile
setlocal bufhidden=hide
setlocal noswapfile
setlocal nonumber
setlocal norelativenumber
setlocal signcolumn=no
setlocal nomodifiable

nnoremap <buffer><silent> <LeftMouse> <LeftMouse>:call copylot#chat#click()<CR>

" 高亮
syntax match copylotFenceLine "^```.*" contains=copylotButton,copylotFence
syntax match copylotFence "^```\s*\w*" contained
syntax match copylotButton "\[.\{-}\]" contained
highlight default copylotFence ctermfg=lightred guifg=#FF8888
highlight def link copylotButton Question

let b:current_syntax = "copylotchat"
