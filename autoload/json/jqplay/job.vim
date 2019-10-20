" ==============================================================================
" Integration of jq (the command-line JSON processor) into Vim
" File:         autoload/json/jqplay/job.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  Oct 20, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

function! s:prepared_buffer(in_buf, start_line, end_line)
    let temp = bufnr('__job_in_buf__', 1)

    if !bufloaded(temp)
        call setbufvar(temp, '&swapfile', 0)
        call setbufvar(temp, '&buflisted', 0)
        call setbufvar(temp, '&buftype', 'nofile')
        call setbufvar(temp, '&bufhidden', 'hide')
        if exists('*bufload')
            silent call bufload(temp)
        else
            silent execute 'keepalt sbuffer' temp
            close
        endif
    endif

    let input = getbufline(a:in_buf, a:start_line, a:end_line)
    let last_line = input[-1]
    let input[-1] = last_line[0:strridx(last_line, ',')-1]
    silent call deletebufline(temp, 1, '$')
    call setbufline(temp, 1, input)

    return temp
endfunction

function! json#jqplay#job#filter(in_buf, start_line, end_line, out_buf, jq_cmd) abort
    if exists('g:jq_job') && job_status(g:jq_job) ==# 'run'
        call job_stop(g:jq_job)
    endif

    " If end_line contains a trailing comma, remove it before piping to jq
    if getbufline(a:in_buf, a:end_line)[0] =~# ',\s*$'
        let in_buf = s:prepared_buffer(a:in_buf, a:start_line, a:end_line)
        let opts = {'in_buf': in_buf}
    else
        let opts = {
                \ 'in_buf': a:in_buf,
                \ 'in_top': a:start_line,
                \ 'in_bot': a:end_line
                \ }
    endif

    " FIXME Vim won't redraw statusline when text is appended to buffer
    call extend(opts, {
            \ 'in_io': 'buffer',
            \ 'out_cb': {_,msg -> appendbufline(a:out_buf, '$', msg)},
            \ 'err_cb': {_,msg -> appendbufline(a:out_buf, '$', '// ' . msg)},
            \ 'close_cb': {... -> deletebufline(a:out_buf, 1)}
            \ })

    " https://github.com/vim/vim/issues/4688
    try
        let g:jq_job = job_start([&shell, &shellcmdflag, a:jq_cmd], opts)
    catch /^Vim\%((\a\+)\)\=:E631:/
    endtry
endfunction

function! json#jqplay#job#stophow(arglead, cmdline, cursorpos) abort
    return join(['term', 'hup', 'quit', 'int', 'kill'], "\n")
endfunction

function! json#jqplay#job#stop(...) abort
    if exists('g:jq_job')
        return job_stop(g:jq_job, a:0 ? a:1 : 'term')
    endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
