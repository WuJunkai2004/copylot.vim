" plugin name: Fitten Code vim
" plugin version: 0.2.1

if exists("g:loaded_fittenchat")
    finish
endif
let g:loaded_fittenchat = 1
let g:fittenchat_name = 'FittenChatBar'
let g:fittenchat_lang = get(g:, 'fittenchat_lang', 'zh')
let g:fittenchat_prom = {
\   'zh': "请完全使用中文回答。",
\   'en': "Please use English to answer."
\}
let g:fittenchat_data = {
\   'entry_border': 1,
\   'cursor_lin': 0,
\   'cursor_col': 0,
\   'is_welcame': v:false,
\   'mode': 'uninit',
\   'apikey' : '',
\   'access' : '',
\   'history': []
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
        call FittenRefresh()
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

function! FittenPrint(string, ...) abort
    let l:win_nr = bufwinnr('^' . g:fittenchat_name . '$')
    if l:win_nr == -1
        return
    endif
    execute l:win_nr . 'wincmd w'
    setlocal modifiable
    let l:force_new_line = a:0 > 0 ? a:1 : v:false
    if l:force_new_line
        call append('$', '')
    endif
    let l:strings = split(a:string, "\n", v:true)
    let l:text = getline('$') . l:strings[0]
    call setline(line('$'), l:text)
    call append('$', l:strings[1:])
    let g:fittenchat_data.entry_border = line('$')
    setlocal nomodifiable
endfunction

function! FittenChatEntryStart() abort
    call FittenPrint("> _question:_\n")
    setlocal modifiable
    let g:fittenchat_data.entry_border = line('$') - 1
    let g:fittenchat_data.cursor_lin = line('$')
    let g:fittenchat_data.cursor_col = 1
    call cursor(g:fittenchat_data.cursor_lin, g:fittenchat_data.cursor_col)
    call s:SwitchMode('entry')
    startinsert
endfunction

function! FittenChatEntryEnd() abort
    if line('.') != line('$') || !empty(getline(line('.')))
        call feedkeys("\<CR>", 'n')
        return
    endif
    call s:SwitchMode('answer')
    setlocal nomodifiable
    let l:context = join(getline(g:fittenchat_data.entry_border + 1, line('$') - 1), "\n")
    call FittenPrint("> _answer:_\n")
    call FittenQuery(l:context)
    stopinsert
endfunction


function! s:SwitchMode(new_mode) abort
    if a:new_mode == g:fittenchat_data['mode']
        return
    endif
    call s:ClearMapping()
    call s:DisableInsert()
    let g:fittenchat_data['mode'] = a:new_mode
    if a:new_mode == 'show'
        nnoremap <buffer><silent> q :call FittenChatEntryStart()<CR>
    elseif a:new_mode == 'entry'
        call s:EnableInsert()
        nnoremap <buffer><silent> <CR> :call FittenChatEntryEnd()<CR>
        inoremap <buffer><silent> <CR> <C-O>:call FittenChatEntryEnd()<CR>
        inoremap <buffer><expr><silent> <Bs> <SID>GuardDelete()
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
    silent! iunmap <buffer> <Bs>
    silent! autocmd! FittenChatEvents
endfunction

function! s:DisableInsert() abort
    " 禁用 Insert 模式系列按键
    nnoremap <buffer><silent> i <Nop>
    nnoremap <buffer><silent> I <Nop>
    nnoremap <buffer><silent> a <Nop>
    nnoremap <buffer><silent> A <Nop>
    nnoremap <buffer><silent> o <Nop>
    nnoremap <buffer><silent> O <Nop>
    " 禁用 Substitute/Change 模式系列按键
    nnoremap <buffer><silent> s <Nop>
    nnoremap <buffer><silent> S <Nop>
    nnoremap <buffer><silent> c <Nop>
    nnoremap <buffer><silent> C <Nop>
    " 禁用 Replace 模式系列按键
    nnoremap <buffer><silent> R <Nop>
endfunction

function! s:EnableInsert() abort
    " 恢复 Insert 模式系列按键
    silent! nunmap <buffer> i
    silent! nunmap <buffer> I
    silent! nunmap <buffer> a
    silent! nunmap <buffer> A
    silent! nunmap <buffer> o
    silent! nunmap <buffer> O
    " 恢复 Substitute/Change 模式系列按键
    silent! nunmap <buffer> s
    silent! nunmap <buffer> S
    silent! nunmap <buffer> c
    silent! nunmap <buffer> C
    " 恢复 Replace 模式系列按键
    silent! nunmap <buffer> R
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
        let g:fittenchat_data.cursor_col = 1
    endif
    call cursor(g:fittenchat_data.cursor_lin, g:fittenchat_data.cursor_col)
endfunction

function! s:GuardDelete() abort
    if line('.') == g:fittenchat_data.entry_border + 1 && col('.') == 1
        return ""
    endif
    return "\<Bs>"
endfunction

function! s:AnswerGet(msg) abort
    "call FittenPrint("[Get]: " . a:msg . "\n")
    let l:res = json_decode(a:msg)
    if has_key(l:res, 'usage')
        call FittenPrint(repeat('—', 21) . "\n", v:true)
        call s:SwitchMode('show')
        return
    endif
    if has_key(l:res, 'detail')
        call FittenPrint("[error]: " . l:res.detail . "\n", v:true)
        call FittenPrint(repeat('—', 21) . "\n")
        return
    endif
    let l:msg = util#decode(l:res.delta)
    let g:fittenchat_data.history[-1].asst .= l:msg
    call FittenPrint(l:msg)
endfunction


function! FittenRefresh() abort
    let l:cert = json_decode(join(readfile($HOME . '/.vim/.FittenToken'), "\n"))
    let g:fittenchat_data.apikey = l:cert.user_id

    let l:refresh_url = 'https://fc.fittenlab.cn/codeuser/auth/refresh_access_token'
    let l:refresh_data = {}
    let l:refresh_head = [
\       ["Authorization", "Bearer " . l:cert.refresh_token]
\   ]

    let l:refresh_res = util#post(l:refresh_url, l:refresh_head, l:refresh_data)

    if has_key(l:refresh_res, 'access_token')
        let g:fittenchat_data.access = l:refresh_res.access_token
        return v:true
    endif
    return v:false
endfunction

function! FittenPrompt(quesion) abort
    let l:prompt = []

    let l:system = get(g:fittenchat_prom, g:fittenchat_lang, g:fittenchat_prom.zh)
    call add(l:prompt, "<|system|>\n" . l:system . "\n<|end|>")

    let l:history = []
    for l:item in g:fittenchat_data.history
        let l:local = "<|user|>\n" . l:item.user . "\n<|end|>\n<|assistant|>\n" . l:item.asst . "\n<|end|>"
    endfor
    if !empty(l:history)
        call add(l:prompt, join(l:history, "\n"))
    endif
    call add(g:fittenchat_data.history, {"user": a:quesion, "asst": ""})

    call add(l:prompt, "<|user|>\n" . a:quesion . "\n<|end|>\n<|assistant|>\n")

    return join(l:prompt, "\n")
endfunction

function! FittenQuery(question) abort
    if empty(g:fittenchat_data.access)
        if !FittenRefresh()
            call FittenPrint("*[error]: access token refresh failed"
            return
        endif
    endif

    let l:base_url = 'https://fc.fittenlab.cn/codeapi/chat_auth'
    let l:chat_url = l:base_url . '?apikey=' . g:fittenchat_data.apikey
    let l:chat_head = [
\       ['Authorization', 'Bearer ' . g:fittenchat_data.access]
\   ]
    let l:chat_data = {
\       "inputs": FittenPrompt(a:question),
\       "ft_token": g:fittenchat_data.apikey
\   }

    call util#stream(l:chat_url, l:chat_head, l:chat_data, function('s:AnswerGet'))
endfunction

function! FittenClick() abort

endfunction
