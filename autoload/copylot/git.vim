function! copylot#git#commit_message() abort
    call copylot#server#start()
    let l:data = {
        \ 'action': 'commit_message',
    \}
    call copylot#server#action(l:data)
endfunction

function! copylot#git#handle_gitmsg(response) abort
    let l:msg = get(a:response, 'content', '')
    if empty(l:msg)
        return
    endif

    " If we are in a git commit buffer, insert the message
    if &filetype ==# 'gitcommit' || expand('%:t') ==# 'COMMIT_EDITMSG'
        call append(0, split(l:msg, "\n") + [''])
        return
    endif

    " Otherwise, show it in the chat sidebar
    call copylot#chat#toggle()
    call copylot#chat#print("\n> _Generated Commit Message_:\n", 1)
    call copylot#chat#print(l:msg, 1)
    call copylot#chat#print("\n————————————", 1)
endfunction