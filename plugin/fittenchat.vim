" plugin name: Fitten Code vim
" plugin version: 0.2.1

if exists("g:loaded_fittenchat")
    finish
endif
let g:loaded_fittenchat = 1
let g:fittenchat_name = 'FittenChatBar'
let g:fittenchat_data = {
\   'entry_border': 1,
\   'cursor_lin': 0,
\   'cursor_col': 0,
\   'is_welcame': v:false,
\   'mode': 'uninit',
\}

function! FittenChatToggle() abort
    let l:win_nr = bufwinnr('^' . g:fittenchat_name. '$')
    if l:win_nr != -1
        execute l:win_nr . 'close'
        autocmd! FittenChatResizeGroup
        return
    endif

    execute 'topleft vnew ' . g:fittenchat_name
    setlocal filetype=fittenchat
    setlocal nobuflisted
    call FittenChatResize()

    if !g:fittenchat_data.is_welcame
        call FittenPrint("Welcome to __FittenCode__!\n'q' for ask questions\n" . repeat('=', 21) . "\n")
        let g:fittenchat_data.is_welcame = v:true
    endif

    augroup FittenChatResizeGroup
        autocmd!
        autocmd VimResized,WinEnter,BufEnter * call FittenChatResize()
    augroup END

    call s:SwitchMode('show')
endfunction

function! FittenChatResize()
    let l:win_nr = bufwinnr('^' . g:fittenchat_name . '$')
    if l:win_nr != -1
        let l:current_win = winnr()
        execute l:win_nr . 'wincmd w'
        execute 'vertical resize 30'
        execute l:current_win . 'wincmd w'
    endif
endfunction

function! FittenPrint(string) abort
    let l:win_nr = bufwinnr('^' . g:fittenchat_name . '$')
    if l:win_nr == -1
        return
    endif
    execute l:win_nr . 'wincmd w'
    setlocal modifiable
    let l:strings = split(a:string, "\n", v:true)
    let l:text = getline(g:fittenchat_data.entry_border) . l:strings[0]
    call setline(g:fittenchat_data.entry_border, l:text)
    call append('$', l:strings[1:])
    let g:fittenchat_data.entry_border = line('$')
    setlocal nomodifiable
endfunction

function! FittenChatEntryStart() abort
    call FittenPrint("> question:\n")
    setlocal modifiable
    let g:fittenchat_data.entry_border = line('$') - 1
    let g:fittenchat_data.cursor_lin = line('$')
    let g:fittenchat_data.cursor_col = 0
    call cursor(g:fittenchat_data.cursor_lin, g:fittenchat_data.cursor_col)
    call s:SwitchMode('entry')
    execute 'startinsert'
endfunction


function! s:SwitchMode(new_mode) abort
    if a:new_mode == g:fittenchat_data['mode']
        return
    endif
    call s:ClearMapping()
    let g:fittenchat_data['mode'] = a:new_mode
    if a:new_mode == 'show'
        nnoremap <buffer><silent> q :call FittenChatEntryStart()<CR>
    elseif a:new_mode == 'entry'
        nnoremap <buffer><silent> <CR> :call FittenChatEntryEnd()<CR>
        inoremap <buffer><silent> <CR> <C-O>:call FittenChatEntryEnd()<CR>
        inoremap <buffer><silent> <S-Enter> <CR>
        inoremap <buffer><expr><silent> <Del> <SID>s:GuardDelete()
        augroup FittenChatEvents
            autocmd!
            autocmd CursorMoved,CursorMovedI <buffer> call s:GuardCursor()
        augroup END
    endif
endfunction

function! s:ClearMapping() abort
    silent! nunmap <buffer> q
    silent! nunmap <buffer> <CR>
    silent! iunmap <buffer> <CR>
    silent! iunmap <buffer> <S-Enter>
    silent! iunmap <buffer> <Del>
    silent! autocmd! FittenChatEvents
endfunction

function! s:GuardCursor() abort
    " no in the limit
    if line('.') > g:fittenchat_data.entry_border
        let g:fittenchat_data.cursor_lin = line('.')
        let g:fittenchat_data.cursor_col = col('.')
        return
    endif

    " out of the limit
    if line('$') < g:fittenchat_data.cursor_lin
        while line('$') < g:fittenchat_data.cursor_lin
            call append('$', '')
        endwhile
        let g:fittenchat_data.cursor_col = 0
    endif
    call cursor(g:fittenchat_data.cursor_lin, g:fittenchat_data.cursor_col)
endfunction

function! s:GuardDelete() abort
    if line('.') == g:fittenchat_data.entry_border + 1 && col('.') == 0
        return ""
    endif
    return "\<Del>"
endfunction
