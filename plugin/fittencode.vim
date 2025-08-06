" plugin name: Fitten Code vim
" plugin version: 0.2.1

if exists("g:loaded_fittencode")
    finish
endif
let g:loaded_fittencode = 1
let g:accept_just_now = 0

let s:hlgroup = 'FittenSuggestion'
function! SetSuggestionStyle() abort
    if &t_Co == 256
        hi FittenSuggestion guifg=#808080 ctermfg=244
    else
        hi FittenSuggestion guifg=#808080 ctermfg=8
    endif
    if empty(prop_type_get(s:hlgroup))
        call prop_type_add(s:hlgroup, {'highlight': s:hlgroup})
    endif
endfunction

function! Fittenlogin(account, password)
    let l:login_url = 'https://fc.fittenlab.cn/codeuser/login'
    let l:login_data = { 
\       "username": a:account,
\       "password": a:password
\   }
    let l:login_res = util#post(l:login_url, [], l:login_data)

    if v:shell_error || !has_key(l:login_res, 'code') || l:login_res.code != 200
        echo "Login failed"
        return
    endif

    let l:user_token = l:login_res.data.token

    let l:token_url = 'https://fc.fittenlab.cn/codeuser/get_ft_token'
    let l:token_head = [
\       ['Authorization', 'Bearer '. l:user_token]
\   ]
    let l:token_res = util#get(l:token_url, l:token_head)

    if v:shell_error || !has_key(l:token_res, 'data')
        echo "Login failed"
        return
    endif

    let l:apikey = l:token_res.data.fico_token
    call writefile([l:apikey], $HOME . '/.vim/.FittenToken')

    echo "Login successful, API key saved"
    let g:fitten_login_status = 1
endfunction

command! -nargs=+ Fittenlogin call Fittenlogin(<f-args>)

function! Fittenlogout()
    if filereadable($HOME . '/.vim/.FittenToken')
        call delete($HOME . '/.vim/.FittenToken')
        echo "Logged out successfully"
    else
        echo "You are already logged out"
    endif
endfunction

command! Fittenlogout call Fittenlogout()


function! CheckLoginStatus()
    if filereadable($HOME . '/.vim/.FittenToken')
"        echo "Logged in"
        return 1
    else
"        echo "Not logged in"
        return 0
    endif
endfunction

function! ClearCompletion()
    if exists('b:fitten_suggestion')
        unlet! b:fitten_suggestion
        call prop_remove({'type': s:hlgroup, 'all': v:true})
    endif
endfunction

function! ClearCompletionByCursorMoved()
    if exists('g:accept_just_now') && g:accept_just_now == 2
        let g:accept_just_now = 1
    endif
    if exists('b:fitten_suggestion')
        call ClearCompletion()
    endif
endfunction

function! CodeCompletion()
    call ClearCompletion()

    let l:filename = substitute(expand('%'), '\\', '/', 'g')

    let l:file_content = join(getline(1, '$'), "\n")
    let l:line_num = line('.')
    let l:col_num = getcurpos()[2]

    let l:prefix = join(getline(1, l:line_num - 1), '\n')
    if !empty(l:prefix)
        let l:prefix = l:prefix . '\n'
    endif
    let l:prefix = l:prefix . strpart(getline(l:line_num), 0, l:col_num - 1)

    let l:suffix = strpart(getline(l:line_num), l:col_num - 1)
    if l:line_num < line('$')
        let l:suffix = l:suffix . '\n' . join(getline(l:line_num + 1, '$'), '\n')
    endif

    let l:prompt = "!FCPREFIX!" . l:prefix . "!FCSUFFIX!" . l:suffix . "!FCMIDDLE!"
    " replace \\n to \n
    let l:prompt = substitute(l:prompt, '\\n', '\n', 'g')
    " replace \\t to \t
    let l:prompt = substitute(l:prompt, '\\t', '\t', 'g')
    let l:token = join(readfile($HOME . '/.vim/.FittenToken'), "\n")

    let l:params = {
\       "inputs": l:prompt,
\       "meta_datas": {
\           "filename": l:filename
\       }
\   }

    let l:server_url = 'https://fc.fittenlab.cn/codeapi/completion/generate_one_stage/'
    let l:requst_url = l:server_url . l:token . '?ide=vim&v=0.2.1'
    let l:response = util#post(l:requst_url, [], l:params)

    if v:shell_error
        echow "Request failed"
        return
    endif

    if !has_key(l:response, 'generated_text')
        return
    endif

    let l:generated_text = l:response.generated_text
    let l:generated_text = substitute(l:generated_text, '<.endoftext.>', '', 'g')

    if empty(l:generated_text)
        echow "Fitten Code: No More Suggestions"
        call timer_start(1500, {-> execute('echo ""')})
        return
    endif

    let l:text = split(l:generated_text, "\n", 1)
    if empty(l:text[-1])
        call remove(l:text, -1)
    endif
    let l:text = map(l:text, 'substitute(v:val, "\t", repeat(" ", &ts), "g")')

    let l:is_first_line = v:true
    for line in text
        if empty(line)
            let line = " "
        endif
        if l:is_first_line is v:true
            let l:is_first_line = v:false
            call prop_add(line('.'), l:col_num, {'type': s:hlgroup, 'text': line})
        else
            call prop_add(line('.'), 0, {'type': s:hlgroup, 'text_align': 'below', 'text': line})
        endif
    endfor

    let b:fitten_suggestion = l:generated_text
endfunction

function! CodeAutoCompletion()
    if g:fitten_login_status == 0
        return ""
    endif
    if !exists('g:accept_just_now') || g:accept_just_now == 1 || g:accept_just_now == 2
        let g:accept_just_now = g:accept_just_now - 1
        return ""
    endif
    if col('.') == col('$')
        call CodeCompletion()
        return ""
    endif
    if empty(substitute(getline('.')[col('.') - 1:], '\s', '', 'g'))
        call CodeCompletion()
        return ""
    endif
endfunction

function! FittenAcceptMain()
    echo "Accept"

    if mode() !~# '^[iR]' || !exists('b:fitten_suggestion')
        return ''
    endif

    let l:text = b:fitten_suggestion

    call ClearCompletion()

    return l:text
endfunction

function! FittenInsert(text, is_first_line) abort
    if a:is_first_line == v:false
        call append('.', '')
        let l:line = line('.') + 1
    else
        let l:line = line('.')
    endif
    let l:col = col('.')
    let l:oldline = getline(l:line)
    let l:prefix = strpart(l:oldline, 0, l:col-1)
    let l:suffix = strpart(l:oldline, l:col-1)
    let l:newline = l:prefix . a:text . l:suffix
    call setline(l:line, l:newline)
    call cursor(l:line, l:col + len(a:text))
endfunction

function FittenAccept()
    let g:accept_just_now = 2

    let l:accept = FittenAcceptMain()
    if empty(l:accept)
        let l:feed = pumvisible() ? "\<C-N>" : "\<Tab>"
        let l:feed = g:fitten_accept_key == '\t' ? l:feed : g:fitten_accept_key
        call feedkeys(l:feed, 'n')
        return
    endif

    let l:accept_lines = split(l:accept, "\n", v:true)
    let l:is_first_line = v:true
    for line in l:accept_lines
        call FittenInsert(line, l:is_first_line)
        let l:is_first_line = v:false
    endfor
endfunction

function! FittenAcceptable()
    return (mode() !~# '^[iR]' || !exists('b:fitten_suggestion')) ? 0 : 1
endfunction

let g:fitten_trigger         = get(g:, 'fitten_trigger',         "\<C-l>")
let g:fitten_accept_key      = get(g:, 'fitten_accept_key',      "\<Tab>")
let g:fitten_login_status    = get(g:, 'fitten_login_status',    CheckLoginStatus())
let g:fitten_auto_completion = get(g:, 'fitten_auto_completion', 0) 
function! FittenMapping()
    execute "inoremap" keytrans(g:fitten_trigger) '<Cmd>call CodeCompletion()<CR>'
    execute 'inoremap' keytrans(g:fitten_accept_key) '<Cmd>call FittenAccept()<CR>'
endfunction

command! FittenAutoCompletionOn let g:fitten_auto_completion = 1 | echo 'Fitten Code Auto Completion Enabled'

command! FittenAutoCompletionOff let g:fitten_auto_completion = 0 | echo 'Fitten Code Auto Completion Disabled'

augroup fittencode
    autocmd!
    autocmd CursorMovedI * call ClearCompletionByCursorMoved()
    autocmd InsertLeave  * call ClearCompletion()
    autocmd BufLeave     * call ClearCompletion()
    autocmd ColorScheme,VimEnter * call SetSuggestionStyle()
    " Map tab using vim enter so it occurs after all other sourcing.
    autocmd VimEnter             * call FittenMapping()
    set updatetime=1500
    autocmd CursorHoldI  * if g:fitten_auto_completion == 1 | call CodeAutoCompletion() | endif
augroup END
