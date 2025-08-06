" plugin name: Utilities for Fitten Code
" plugin version: 0.1.0

if exists("g:loaded_fittenutil")
    finish
endif  
let g:loaded_fittenutil = 1


function! util#get(url, headers) abort
    let l:header_parts = []
    for l:item in items(a:headers)
        let l:k = l:item[0]
        let l:v = l:item[1]
        call add(l:header_parts, '-H ' . shellescape(l:k . ': ' . l:v))
    endfor

    let l:cmd = 'curl -s ' . join(l:header_parts, ' ') . ' ' . shellescape(a:url)
    let l:response = system(l:cmd)
    return json_decode(l:response)
endfunction


function! util#post(url, headers, datas) abort
    let l:header_parts = ['-H "Content-Type: application/json"']
    for l:item in items(a:headers)
        let l:k = l:item[0]
        let l:v = l:item[1]
        call add(l:header_parts, '-H ' . shellescape(l:k . ': ' . l:v))
    endfor

    let l:tmp_file = tempname()
    call writefile([json_encode(a:datas)], l:tmp_file)

    let l:cmd = 'curl -s -X POST ' . join(l:header_parts, ' ') . ' -d @' . l:tmp_file . ' ' . shellescape(a:url)
    let l:response = system(l:cmd)
    call delete(l:tmp_file)
    return json_decode(l:response)
endfunction


function! util#stream(url, headers, datas, callback) abort

endfunction
