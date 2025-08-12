" plugin name: Fitten Code - Chatbar configuration
" plugin version: 0.2.1

if exists("b:current_syntax")
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

nnoremap <buffer><silent> <LeftMouse> <LeftMouse>:call FittenClick()<CR>

" 高亮
syntax match FittenCodeFenceLine "^```.*" contains=FittenButton,FittenCodeFence
syntax match FittenCodeFence "^```\s*\w*" contained
syntax match FittenButton "\[.\{-}\]" contained
highlight default FittenCodeFence ctermfg=lightred guifg=#FF8888
highlight def link FittenButton Question

let b:current_syntax = "fittenchat"
