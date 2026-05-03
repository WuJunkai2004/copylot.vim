" plugin name: Copylot.vim
" plugin version: 0.1.0

if exists('g:loaded_copylot')
    finish
endif
let g:loaded_copylot = 1

" Command to toggle the Copylot Chat sidebar
command! CopylotChat call copylot#chat#toggle()

" Command to generate a Git Commit message based on staged changes
command! CopylotCommit call copylot#git#commit_message()
