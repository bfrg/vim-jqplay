" ==============================================================================
" Integration of jq (the command-line JSON processor) into Vim
" File:         autoload/json/jqplay/system.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  July 25, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

function! json#jqplay#system#filter(in_buf, start_line, end_line, out_buf, jq_cmd) abort
    let l:json_input = getbufline(a:in_buf, a:start_line, a:end_line)
    if l:json_input[-1] =~# ',\s*$'
        let l:last_line = l:json_input[-1]
        let l:json_input[-1] = l:last_line[0:strridx(l:last_line, ',')-1]
    endif
    let l:output = system(a:jq_cmd, l:json_input)
    call setbufline(a:out_buf, 1, split(l:output, "\n"))
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
