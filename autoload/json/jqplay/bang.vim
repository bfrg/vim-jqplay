" ==============================================================================
" Integration of jq (the command-line JSON processor) into Vim
" File:         autoload/json/jqplay/bang.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  Oct 19, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

function! json#jqplay#bang#filter(start_line, end_line, maxindent, jq_cmd) abort
    let trailing_comma = 0
    if getline(a:end_line) =~# ',\s*$'
        let trailing_comma = 1
        let last_line = getline(a:end_line)
        call setline(a:end_line, last_line[0:strridx(last_line, ',')-1])
    endif

    execute printf('%d,%d!%s', a:start_line, a:end_line, escape(a:jq_cmd, '!#%'))

    if trailing_comma
        call setline("']", getline("']") . ',')
    endif

    if a:maxindent > getpos("']")[1] - getpos("'[")[1]
            \ && a:jq_cmd !~# '\<--compact-output\>\|\<-c\>'
            \ && a:start_line != 1
            \ && a:end_line != line('$')
        silent normal! '[=']
        call setpos("']", [0, getpos("']")[1], len(getline(getpos("']")[1])), 0])
    endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
