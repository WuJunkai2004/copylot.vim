" plugin name: copylot - Chatbar Syntax

if exists('b:current_syntax')
    finish
endif

" Load markdown syntax as base
runtime! syntax/markdown.vim
unlet! b:current_syntax

" Custom highlighting for Copylot buttons and fences
syntax match copylotFenceLine "^```.*" contains=copylotButton,copylotFence
syntax match copylotFence "^```\s*\w*" contained
syntax match copylotButton "\[.\{-}\]" contained

highlight default copylotFence ctermfg=lightred guifg=#FF8888
highlight def link copylotButton Question

let b:current_syntax = "copylotchat"
