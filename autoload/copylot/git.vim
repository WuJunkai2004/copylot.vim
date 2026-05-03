function! copylot#git#commit_message() abort
    call copylot#server#start()
    let l:data = {
        \ 'action': 'commit_message',
    \}
    call copylot#server#action(l:data)
endfunction
