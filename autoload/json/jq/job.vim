" ==============================================================================
" Integration of jq (the command-line JSON processor) into Vim
" File:         autoload/json/jq/job.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  July 25, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

function! json#jq#job#filter(in_buf, start_line, end_line, out_buf, jq_cmd) abort
    if exists('g:jq_job') && job_status(g:jq_job) ==# 'run'
        call job_stop(g:jq_job)
    endif

    " Issue: https://github.com/vim/vim/issues/4688
    try
        let g:jq_job = job_start(
                \ [&shell, &shellcmdflag, a:jq_cmd], {
                \ 'in_io': 'buffer',
                \ 'in_buf': a:in_buf,
                \ 'in_top': a:start_line,
                \ 'in_bot': a:end_line,
                \ 'out_io': 'buffer',
                \ 'out_buf': a:out_buf,
                \ 'err_io': 'out'
                \ })
    catch /^Vim\%((\a\+)\)\=:E631:/
    endtry
endfunction

function! json#jq#job#stop(...) abort
    if exists('g:jq_job')
        return job_stop(g:jq_job, a:0 ? a:1 : 'term')
    endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
