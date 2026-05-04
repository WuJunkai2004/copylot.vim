function! copylot#git#auto_commit_message() abort
    if &filetype ==# 'gitcommit' || expand('%:t') ==# 'COMMIT_EDITMSG'
        call append(0, "# Copylot is generating a commit message for you... Please wait.")
        call cursor(1, 1)
    endif
    call copylot#git#commit_message()
endfunction

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
        " Remove the placeholder if it exists
        if getline(1) ==# "# Copylot is generating a commit message for you... Please wait."
            1delete _
        endif

        " Optimize message format: first line, then a blank line, then the rest (no more blank lines)
        let l:lines = split(l:msg, "\n")
        let l:lines = filter(l:lines, 'v:val =~# "\\S"')
        if empty(l:lines)
            return
        endif

        let l:final_msg = [l:lines[0], '']
        if len(l:lines) > 1
            call extend(l:final_msg, l:lines[1:])
        endif

        call append(0, l:final_msg)
        call cursor(1, 1)
        return
    endif

    " Otherwise, show it in the chat sidebar
    call copylot#chat#toggle()
    call copylot#chat#print("\n> _Generated Commit Message_:\n", 1)
    call copylot#chat#print(l:msg, 1)
    call copylot#chat#print("\n————————————", 1)
endfunction