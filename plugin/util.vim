" plugin name: Utilities for Fitten Code
" plugin version: 0.1.0

if exists("g:loaded_fittenutil")
    finish
endif  
let g:loaded_fittenutil = 1


function! util#get(url, headers) abort
    let l:header_parts = []
    for l:item in a:headers
        let l:k = l:item[0]
        let l:v = l:item[1]
        call add(l:header_parts, '-H ' . shellescape(l:k . ': ' . l:v))
    endfor

    let l:cmd = 'curl --connect-timeout 10 -m 30 -s ' . join(l:header_parts, ' ') . ' ' . shellescape(a:url)
    let l:response = system(l:cmd)
    return json_decode(l:response)
endfunction


function! util#post(url, headers, datas) abort
    let l:header_parts = ['-H "Content-Type: application/json"']
    for l:item in a:headers
        let l:k = l:item[0]
        let l:v = l:item[1]
        call add(l:header_parts, '-H ' . shellescape(l:k . ': ' . l:v))
    endfor

    let l:tmp_file = tempname()
    call writefile([json_encode(a:datas)], l:tmp_file)

    let l:cmd = 'curl --connect-timeout 10 -m 30 -s -X POST ' . join(l:header_parts, ' ') . ' -d @' . l:tmp_file . ' ' . shellescape(a:url)
    let l:response = system(l:cmd)
    call delete(l:tmp_file)
    return json_decode(l:response)
endfunction


function! util#stream(url, headers, datas, callback) abort
    let l:header_parts = ['-H', 'Content-Type: application/json']
    for l:item in a:headers
        let l:k = l:item[0]
        let l:v = l:item[1]
        call extend(l:header_parts, ['-H', l:k . ': ' . l:v])
    endfor

    let l:tmp_file = tempname()
    call writefile([json_encode(a:datas)], l:tmp_file)

    let l:cmd = ['curl', '--connect-timeout', '10', '-s', '-N', '-X', 'POST']
    call extend(l:cmd, l:header_parts)
    call extend(l:cmd, ['-d', '@' . l:tmp_file])
    call extend(l:cmd, [a:url])

    let l:context = {
\       'callback' : a:callback,
\       'tempfile' : l:tmp_file,
\    }

    let l:opts = {
\       'out_io': 'pipe',
\       'out_cb': function('s:on_stdout', [], l:context),
\       'exit_cb': function('s:on_exit', [], l:context),
\   }

    return job_start(l:cmd, l:opts)
endfunction

function! s:on_stdout(job, msg) dict abort
    let l:The_callback = self.callback
    call l:The_callback(a:msg)
endfunction

function! s:on_exit(job, msg) dict abort
    if filereadable(self.tempfile)
        call delete(self.tempfile)
    endif
endfunction


function! util#decode(string) abort
    return substitute(a:string, '\\u\x\{4}', '\=nr2char(str2nr(submatch(1), 16))', 'g')
endfunction
