" plugin name: Fitten Code - Chatbar configuration
" plugin version: 0.2.1

if exists('g:loaded_fittenchat_config')
    finish
endif
let g:loaded_fittenchat_config = 1

" 缓冲区属性设置
setlocal nobuflisted
setlocal buftype=nofile
setlocal bufhidden=hide
setlocal noswapfile
setlocal nonumber
setlocal norelativenumber
setlocal signcolumn=no
setlocal nowrap
setlocal nomodifiable

" 静态映射：设置“只读”模式下的快捷键
nnoremap <buffer><silent> i <Nop>
nnoremap <buffer><silent> a <Nop>
nnoremap <buffer><silent> o <Nop>
nnoremap <buffer><silent> v <Nop>
nnoremap <buffer><silent> V <Nop>
nnoremap <buffer><silent> <C-v> <Nop>
nnoremap <buffer><silent> <CR> :call fittenchat#handle_button_click()<CR>

" 语法和高亮
syntax match FittenButton "\[.\{-}\]"
highlight def link FittenButton Question

