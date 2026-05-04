" Copylot Chat Sidebar Chat UI Implementation
" Last updated: 2026-03-02

" This module export the below functions:
" - copylot#chat#toggle(): Toggle the visibility of the chat sidebar.
" - copylot#chat#reset(): Reset the chat sidebar to the initial state.
" - copylot#chat#print(text, force_new_line): Print text to the chat sidebar
" - copylot#chat#switch(mode): Switch the chat sidebar mode.
" - copylot#chat#addButtons(): Add action buttons to code blocks in the answer.
" - copylot#chat#click(): Handle click events for action buttons in code blocks.

" And define the below internal functions:
" - s:show_welcome_message(): Show the welcome message in the chat sidebar.
" - s:show_help_message(): Show the help message in the chat sidebar.
" - s:resize_sidebar(): Resize the sidebar to fit the content.
" - s:clear_mappings(): Clear all key mappings in the chat sidebar.
" - s:disable_editing(): Disable editing in the chat sidebar.
" - s:enable_editing(): Enable editing in the chat sidebar.
" - s:input_start(): Start the input mode for asking a question.
" - s:input_end(): End the input mode and submit the question.
" - s:guard_cursor(): Guard the cursor to prevent it from moving outside the input area.
" - s:guard_backspace(): Guard the backspace key to prevent deleting the prompt.
" - s:get_code_block(): Get the code block content under the cursor.
" - s:code_copy(): Copy the code block content to the clipboard.
" - s:code_apply(): Apply the code block content to the previous window.


let s:sidebar_name = 'CopylotChat'
let s:sidebar_buf = -1

" UI State
let s:state = {
\   'mode': 'uninit',
\   'input_border': 1,
\   'answer_border': 0,
\   'cursor_line': 0,
\   'cursor_col': 0,
\   'welcome_done': v:false
\}


function! copylot#chat#toggle() abort
    let l:win_nr = bufwinnr('^' . s:sidebar_name . '$')
    if l:win_nr != -1
        execute l:win_nr . 'close'
        autocmd! CopylotChatResizeGroup
        return
    endif

    call copylot#server#start()

    execute 'topleft vnew ' . s:sidebar_name
    setlocal filetype=copylotchat
    setlocal nobuflisted
    call s:resize_sidebar()

    if !s:state.welcome_done
        call s:show_welcome_message()
        let s:state.welcome_done = v:true
    endif

    augroup CopylotChatResizeGroup
        autocmd!
        autocmd VimResized,WinEnter,BufEnter <buffer> call s:resize_sidebar()
    augroup END

    call copylot#chat#switch('show')
endfunction

function! copylot#chat#reset() abort
    let l:win_nr = bufwinnr('^' . s:sidebar_name . '$')
    if l:win_nr == -1
        return
    endif

    let l:save_win = winnr()
    if l:save_win != l:win_nr
        execute l:win_nr . 'wincmd w'
    endif

    setlocal modifiable
    silent %delete _
    call append('$', '')
    call s:show_welcome_message()
    call copylot#chat#switch('show')
    setlocal nomodifiable

    if l:save_win != l:win_nr
        execute l:save_win . 'wincmd w'
    endif
endfunction


function! copylot#chat#print(text, ...) abort
    let l:win_nr = bufwinnr('^' . s:sidebar_name . '$')
    if l:win_nr == -1
        return
    endif

    let l:save_win = winnr()
    if l:save_win != l:win_nr
        execute l:win_nr . 'wincmd w'
    endif

    setlocal modifiable

    let l:force_new_line = a:0 > 0 ? a:1 : 0
    if l:force_new_line && !empty(getline('$'))
        call append('$', '')
    endif

    let l:lines = split(a:text, "\n", v:true)
    let l:last_text = getline('$') . l:lines[0]
    call setline(line('$'), l:last_text)
    if len(l:lines) > 1
        call append('$', l:lines[1:])
    endif

    let s:state.input_border = line('$')
    setlocal nomodifiable
    normal! G

    if l:save_win != l:win_nr
        execute l:save_win . 'wincmd w'
    endif
endfunction


function! s:show_welcome_message() abort
    let l:welcome = [
    \   "Welcome to __Copylot__!",
    \   "'q' for ask questions",
    \   "'h' for help",
    \   "————————————",
    \   "",
    \]
    call copylot#chat#print(join(l:welcome, "\n"), 1)
endfunction

function! s:show_help_message() abort
    let l:help = [
    \   "'q' - Ask a question. Pressing double 'Enter' after typing will submit your question.",
    \   "'h' - Show this help message.",
    \   "[button] - Clickable buttons next to code blocks for quick actions",
    \   "————————————",
    \   "",
    \]
    call copylot#chat#print(join(l:help, "\n"), 1)
endfunction


function! s:resize_sidebar() abort
    let l:win_nr = bufwinnr('^' . s:sidebar_name . '$')
    if l:win_nr != -1
        let l:current_win = winnr()
        execute l:win_nr . 'wincmd w'
        execute 'vertical resize 30'
        execute l:current_win . 'wincmd w'
    endif
endfunction


function! copylot#chat#switch(new_mode) abort
    let l:win_nr = bufwinnr('^' . s:sidebar_name . '$')
    if l:win_nr == -1
        return
    endif

    let l:save_win = winnr()
    if l:save_win != l:win_nr
        execute l:win_nr . 'wincmd w'
    endif

    if a:new_mode == s:state.mode
        if l:save_win != l:win_nr
            execute l:save_win . 'wincmd w'
        endif
        return
    endif

    call s:clear_mappings()
    call s:disable_editing()

    let s:state.mode = a:new_mode

    if a:new_mode ==# 'show'
        setlocal nomodifiable
        nnoremap <buffer><silent> q :call <SID>input_start()<CR>
        nnoremap <buffer><silent> h :call <SID>show_help_message()<CR>
        nnoremap <buffer><silent> <CR> :call copylot#chat#click()<CR>

    elseif a:new_mode ==# 'input'
        call s:enable_editing()
        nnoremap <buffer><silent> <CR> :call <SID>input_end()<CR>
        inoremap <buffer><silent> <CR> <C-O>:call <SID>input_end()<CR>
        inoremap <buffer><expr><silent> <BS> <SID>guard_backspace()

        augroup CopylotGuard
            autocmd! * <buffer>
            autocmd CursorMoved,CursorMovedI <buffer> call s:guard_cursor()
        augroup END

    elseif a:new_mode ==# 'answer'
        setlocal nomodifiable
    endif

    if l:save_win != l:win_nr
        execute l:save_win . 'wincmd w'
    endif
endfunction


function! s:clear_mappings() abort
    silent! nunmap <buffer> q
    silent! nunmap <buffer> h
    silent! nunmap <buffer> <CR>
    silent! iunmap <buffer> <CR>
    silent! iunmap <buffer> <BS>
    silent! autocmd! CopylotGuard * <buffer>
endfunction


function! s:disable_editing() abort
    for l:k in ['i', 'I', 'a', 'A', 'o', 'O', 's', 'S', 'c', 'C', 'R']
        execute 'nnoremap <buffer><silent> ' . l:k . ' <Nop>'
    endfor
endfunction

function! s:enable_editing() abort
    for l:k in ['i', 'I', 'a', 'A', 'o', 'O', 's', 'S', 'c', 'C', 'R']
        execute 'silent! nunmap <buffer> ' . l:k
    endfor
endfunction


function! s:input_start() abort
    call copylot#chat#print("> _Question_:\n", 1)
    setlocal modifiable
    let s:state.input_border = line('$') - 1
    let s:state.cursor_line = line('$')
    let s:state.cursor_col = 1
    call cursor(s:state.cursor_line, s:state.cursor_col)
    call copylot#chat#switch('input')
    startinsert!
endfunction


function! s:input_end() abort
    " Ported UX: If cursor not at end or line not empty, just act as newline
    if line('.') != line('$') || !empty(getline(line('.')))
        call feedkeys("\<CR>", 'n')
        return
    endif

    let l:prompt = join(getline(s:state.input_border + 1, line('$') - 1), "\n")
    if empty(trim(l:prompt))
        " Cleanup if empty and return to show mode
        setlocal modifiable
        silent execute (s:state.input_border) . ',$delete'
        call append('$', '')
        call copylot#chat#switch('show')
        stopinsert
        return
    endif

    call copylot#chat#switch('answer')
    setlocal nomodifiable
    call copylot#chat#print("> _Answer_:\n", 1)
    let s:state.answer_border = line('$')
    call copylot#server#query(l:prompt)
    stopinsert
endfunction


function! s:guard_cursor() abort
    if line('.') > s:state.input_border
        let s:state.cursor_line = line('.')
        let s:state.cursor_col = col('.')
        return
    endif

    " If buffer was changed/deleted externally
    if line('$') < s:state.cursor_line
        while line('$') < s:state.cursor_line
            call append('$', '')
        endwhile
        let s:state.cursor_col = 1
    endif
    call cursor(s:state.cursor_line, s:state.cursor_col)
endfunction

function! s:guard_backspace() abort
    if line('.') == s:state.input_border + 1 && col('.') == 1
        return ""
    endif
    return "\<BS>"
endfunction

function! copylot#chat#addButtons() abort
    let l:win_nr = bufwinnr('^' . s:sidebar_name . '$')
    if l:win_nr == -1
        return
    endif

    let l:save_win = winnr()
    if l:save_win != l:win_nr
        execute l:win_nr . 'wincmd w'
    endif

    let l:is_upper = 1
    setlocal modifiable
    for l:lnum in range(s:state.answer_border, line('$') - 1)
        let l:line = getline(l:lnum)
        if l:line =~# '^```'
        if l:is_upper
            call setline(l:lnum, l:line . "  [copy] [apply]")
        endif
        let l:is_upper = !l:is_upper
        endif
    endfor
    setlocal nomodifiable

    if l:save_win != l:win_nr
        execute l:save_win . 'wincmd w'
    endif
endfunction

" Ported: Precise column-based click detection
function! copylot#chat#click() abort
    let l:cur_lin = line('.')
    let l:cur_col = col('.')
    let l:str = getline(l:cur_lin)

    if l:str !~# '^```'
        return
    endif

    let l:button_text = ""
    let l:start_search_col = 1
    while l:start_search_col
        let l:match_info = matchstrpos(l:str, '\[.\{-}\]', l:start_search_col)
        if empty(l:match_info[0])
            break
        endif

        let l:match_left = l:match_info[1]
        let l:match_right = l:match_info[2]

        " If cursor is within the brackets
        if l:match_left + 1 < l:cur_col && l:cur_col <= l:match_right
        let l:button_text = l:match_info[0]
        break
        endif
        let l:start_search_col = l:match_right
    endwhile

    if l:button_text ==# "[copy]"
        call s:code_copy()
    elseif l:button_text ==# "[apply]"
        call s:code_apply()
    endif
endfunction

function! s:get_code_block() abort
    let l:lnum = line('.') + 1
    let l:code = []
    while l:lnum <= line('$')
        let l:line = getline(l:lnum)
        if l:line =~# '^```'
            break
        endif
        call add(l:code, l:line)
        let l:lnum += 1
    endwhile
    return l:code
endfunction

function! s:code_copy() abort
    let l:code = join(s:get_code_block(), "\n")
    if has('clipboard')
        let @+ = l:code
    else
        let @" = l:code
        let @c = l:code
    endif
    echom "[Copylot] Code copied to clipboard."
endfunction

function! s:code_apply() abort
    if winnr('#') == 0 | return | endif
    let l:code = s:get_code_block()
    wincmd p
    call append(line('.'), l:code)
    echom "[Copylot] Code applied to previous window."
endfunction