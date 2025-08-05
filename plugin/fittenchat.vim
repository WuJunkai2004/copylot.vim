" plugin name: Fitten Code vim
" plugin version: 0.2.1

if exists("g:loaded_fittenchat")
    finish
endif
let g:loaded_fittenchat = 1
let g:fittenchat_name = 'FittenChatBar'
let g:fittenchat_data = {
\   'current_line': 1,
\   'is_welcame': v:false,
\}
nohlsearch
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
        call FittenPrint("Welcome to FittenCode!\n'q' for ask questions\n" . repeat('=', 21) . "\n")
        let g:fittenchat_data.is_welcame = v:true
    endif

    augroup FittenChatResizeGroup
        autocmd!
        autocmd VimResized,WinEnter,BufEnter * call FittenChatResize()
    augroup END
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
    let l:text = getline(g:fittenchat_data.current_line) . l:strings[0]
    call setline(g:fittenchat_data.current_line, l:text)
    call append('$', l:strings[1:])
    let g:fittenchat_data.current_line = line('$')
    setlocal nomodifiable
endfunction
