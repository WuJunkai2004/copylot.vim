let s:job = v:null
let s:python_script = expand('<sfile>:p:h:h:h') . '/python/copylot.py'
let s:history = []
let s:response_buffer = ''
let s:callback_funs = {
    \ 'answer': function('copylot#server#handle_answer'),
    \ 'ends': function('copylot#server#handle_ends'),
    \ 'error': function('copylot#server#handle_error'),
\}
let s:history_limit = get(g:, 'copylot_history', 20)


function! copylot#server#available() abort
    return executable('python3') || executable('python')
endfunction


function! copylot#server#start() abort
    if !copylot#server#available()
        return
    endif

    if s:job != v:null && job_status(s:job) ==# 'run'
        return
    endif

    let l:python = executable('python3') ? 'python3' : 'python'
    let l:cmd = [l:python, s:python_script]
    if exists('g:copylot_config')
        call add(l:cmd, expand(g:copylot_config))
    endif

    let s:job = job_start(l:cmd, {
        \ 'out_mode': 'raw',
        \ 'in_io': 'pipe',
        \ 'out_io': 'pipe',
        \ 'err_io': 'pipe',
        \ 'out_cb': function('s:on_response'),
        \ 'exit_cb': function('s:on_exit'),
        \ })
endfunction


function! copylot#server#stop() abort
    if s:job != v:null && job_status(s:job) ==# 'run'
        call job_stop(s:job)
        let s:job = v:null
        let s:channel = v:null
    endif
endfunction


function! copylot#server#query(question) abort
    if s:job == v:null || job_status(s:job) !=# 'run'
        call copylot#chat#print('__[Error]__: Server is ' . (s:job == v:null ? 'not running' : job_status(s:job)), 1)
        return
    endif

    call add(s:history, {'role': 'user', 'content': a:question})
    if len(s:history) > s:history_limit
        call remove(s:history, 0)
    endif

    let l:data = {
        \ 'action': 'query',
        \ 'content': s:history,
    \}
    call s:send(l:data)
endfunction


function! s:send(data) abort
    if s:job == v:null || job_status(s:job) !=# 'run'
        return
    endif

    let l:json_req = json_encode(a:data)
    let l:header = 'Content-Length: ' . len(l:json_req) . "\r\n\r\n"
    call ch_sendraw(s:job, l:header . l:json_req)
endfunction


function! s:on_response(channel, msg) abort
    if empty(a:msg)
        return
    endif

    let s:response_buffer .= a:msg
    let l:length_str = matchstr(s:response_buffer, '\zs\d\+\r\n\r\n')[:-4]
    if empty(l:length_str)
        return
    endif
    let l:length_num = str2nr(l:length_str)

    let l:response_text = split(s:response_buffer, "\r\n\r\n")[1]
    if len(l:response_text) < l:length_num
        return
    else
        let s:response_buffer = l:response_text[l:length_num:]
        let l:response_json = l:response_text[:l:length_num - 1]
    endif

    echom 'Received response: ' . l:response_json
    let l:response_json = json_decode(l:response_json)
    if has_key(l:response_json, 'type') && has_key(s:callback_funs, l:response_json.type)
        call call(s:callback_funs[l:response_json.type], [l:response_json])
    endif
endfunction


function! s:on_exit(channel, exit_code) abort
    let s:job = v:null
    let s:response_buffer = ''
endfunction


function! copylot#server#handle_answer(response) abort
    let l:msg = get(a:response, 'content', '')

    if empty(s:history) || s:history[-1].role !=# 'assistant'
        call add(s:history, {'role': 'assistant', 'content': l:msg})
    else
        let s:history[-1].content .= l:msg
    endif

    call copylot#chat#print(l:msg)
endfunction


function! copylot#server#handle_ends(response) abort
    call copylot#chat#print('————————————', 1)
    call copylot#chat#switch('show')
    call copylot#chat#addButtons()
endfunction


function! copylot#server#handle_error(response) abort
    let l:error_msg = get(a:response, 'content', 'Unknown error')
    call copylot#chat#print('__[Error]__: ' . l:error_msg, 1)
    call copylot#chat#print('————————————', 1)
    call copylot#chat#switch('show')
    call copylot#chat#addButtons()
endfunction