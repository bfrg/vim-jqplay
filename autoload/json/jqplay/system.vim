" ==============================================================================
" Integration of jq (the command-line JSON processor) into Vim
" File:         autoload/json/jqplay/system.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  Sep 3, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

function! json#jqplay#system#filter(in_buf, start_line, end_line, out_buf, jq_cmd) abort
    let json_input = getbufline(a:in_buf, a:start_line, a:end_line)
    if json_input[-1] =~# ',\s*$'
        let last_line = json_input[-1]
        let json_input[-1] = last_line[0:strridx(last_line, ',')-1]
    endif
    let output = system(a:jq_cmd, json_input)
    call setbufline(a:out_buf, 1, split(output, "\n"))
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
