" ==============================================================================
" Integration of jq (the command-line JSON processor) into Vim
" File:         autoload/json/jqplay.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  Oct 20, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:defaults = {
        \ 'exe': exepath('jq'),
        \ 'opts': '--tab',
        \ 'async': 1,
        \ 'maxindent': 2048,
        \ 'autocmds': ['InsertLeave', 'TextChanged']
        \ }

function! s:get(key) abort
    let jqplay = get(b:, 'jqplay', get(g:, 'jqplay', {}))
    return has_key(jqplay, a:key) ? get(jqplay, a:key) : get(s:defaults, a:key)
endfunction

function! s:error(msg) abort
    echohl ErrorMsg | echomsg a:msg | echohl None
    return 0
endfunction

function! s:json_scratch(bufname, mods) abort
    let out_buf = bufnr(a:bufname, 1)

    " New buffers returned by bufnr({expr}, 1) are unloaded
    if !bufloaded(out_buf)
        " Setting the filetype at last will allow users to override the other
        " buffer-local options in after/ftplugin/json.vim, or using a FileType
        " autocommand
        call setbufvar(out_buf, '&swapfile', 0)
        call setbufvar(out_buf, '&buflisted', 1)
        call setbufvar(out_buf, '&buftype', 'nofile')
        call setbufvar(out_buf, '&bufhidden', 'hide')
        call setbufvar(out_buf, '&filetype', 'json')
    endif

    " Make sure buffer is visible
    if bufwinnr(out_buf) == -1
        silent execute a:mods 'keepalt sbuffer' out_buf
        wincmd p
    endif

    " Issue: https://github.com/vim/vim/issues/4745
    silent call deletebufline(out_buf, 1, '$')

    return out_buf
endfunction

function! s:jq_scratch(bufname) abort
    let bufnr = bufnr(a:bufname, 1)

    " New buffers returned by bufnr({expr}, 1) are unloaded
    if !bufloaded(bufnr)
        call setbufvar(bufnr, '&swapfile', 0)
        call setbufvar(bufnr, '&buflisted', 1)
        call setbufvar(bufnr, '&buftype', 'nofile')
        call setbufvar(bufnr, '&bufhidden', 'hide')
        call setbufvar(bufnr, '&filetype', 'jq')
    endif

    " Make sure buffer is visible
    if bufwinnr(bufnr) == -1
        silent execute 'botright keepalt sbuffer' bufnr
        resize 10
        wincmd p
    endif

    " Filetype will be overridden when filename ends with .json, like
    " jq-filter:///path/to/inputfile.json, therefore call it again
    call setbufvar(bufnr, '&filetype', 'jq')

    return bufnr
endfunction

" Flag that indicates whether a jqplay session is running
let s:jqplay_open = 0

function! json#jqplay#scratch(mods, jq_opts) abort
    if s:jqplay_open
        return s:error('jqplay: currently only one session per Vim instance is allowed.')
    endif

    let in_buf = bufnr('%')
    let out_name = 'jq-output://' . expand('%')
    let out_buf = s:json_scratch(out_name, a:mods)
    let jqfilter_name = 'jq-filter://' . expand('%')
    let jqfilter_buf = s:jq_scratch(jqfilter_name)
    let jqfilter_file = tempname()

    let jq_cmd = printf('%s %s %s -f %s',
            \ s:get('exe'),
            \ s:get('opts'),
            \ a:jq_opts,
            \ jqfilter_file
            \ )

    let s:jq_ctx = {
            \ 'in_buf': in_buf,
            \ 'out_buf': out_buf,
            \ 'filter_buf': jqfilter_buf,
            \ 'filter_file': jqfilter_file,
            \ 'cmd': jq_cmd
            \ }

    lockvar s:jq_ctx
    let s:jqplay_open = 1

    " FIXME remove buffer-local variables when jqplay session is closed
    call setbufvar(in_buf, 'jq_changedtick', getbufvar(in_buf, 'changedtick'))
    call setbufvar(jqfilter_buf, 'jq_changedtick', getbufvar(jqfilter_buf, 'changedtick'))

    if !empty(s:get('autocmds'))
        call s:set_autocmds()
    endif
endfunction

function! s:set_autocmds() abort
    let events = join(s:get('autocmds'), ',')
    let filter_buf = s:jq_ctx.filter_buf
    let in_buf = s:jq_ctx.in_buf
    let out_buf = s:jq_ctx.out_buf

    augroup jqplay
        autocmd!

        " Run jq when filter or input buffer is modified
        execute printf('autocmd %s <buffer=%d> call s:filter_changed()', events, filter_buf)
        execute printf('autocmd %s <buffer=%d> call s:input_changed()', events, in_buf)

        " Remove autocmds when filter, input or output buffer is deleted/wiped
        execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call json#jqplay#closeall(0)', filter_buf)
        execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call json#jqplay#closeall(0)', in_buf)
        execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call json#jqplay#closeall(0)', out_buf)
    augroup END
endfunction

function! json#jqplay#ctx() abort
    return s:jqplay_open ? s:jq_ctx : {}
endfunction

function! json#jqplay#closeall(bang) abort
    call json#jqplay#stop()
    if a:bang
        noautocmd execute 'bdelete' s:jq_ctx.filter_buf
        noautocmd execute 'bdelete' s:jq_ctx.out_buf
    endif
    unlockvar s:jq_ctx
    let s:jqplay_open = 0
    autocmd! jqplay
    echohl WarningMsg
    echo 'jqplay session closed.'
    echohl None
endfunction

function! s:filter_changed() abort
    let filter_buf = s:jq_ctx.filter_buf
    if getbufvar(filter_buf, 'jq_changedtick') == getbufvar(filter_buf, 'changedtick')
        return
    endif
    call writefile(getbufline(filter_buf, 1, '$'), s:jq_ctx.filter_file)
    call s:runjq(filter_buf)
endfunction

function! s:input_changed() abort
    let in_buf = s:jq_ctx.in_buf
    if getbufvar(in_buf, 'jq_changedtick') == getbufvar(in_buf, 'changedtick')
        return
    endif
    call s:runjq(in_buf)
endfunction

function! s:close_cb(buf, channel) abort
    silent call deletebufline(s:jq_ctx.out_buf, 1)
    call setbufvar(a:buf, 'jq_changedtick', getbufvar(a:buf, 'changedtick'))
endfunction

function! s:runjq(buf) abort
    silent call deletebufline(a:jq_ctx.out_buf, 1, '$')

    if exists('g:jq_job') && job_status(g:jq_job) ==# 'run'
        call job_stop(g:jq_job)
    endif

    " https://github.com/vim/vim/issues/4688
    " E631: write_buf_line(): write failed
    " This occurs only for large files
    try
        let g:jq_job = job_start([&shell, &shellcmdflag, s:jq_ctx.cmd], {
                \ 'in_io': 'buffer',
                \ 'in_buf': s:jq_ctx.in_buf,
                \ 'out_cb': {_,msg -> appendbufline(s:jq_ctx.out_buf, '$', msg)},
                \ 'err_cb': {_,msg -> appendbufline(s:jq_ctx.out_buf, '$', '// ' . msg)},
                \ 'close_cb': function('s:close_cb', [a:buf])
                \ })
    catch /^Vim\%((\a\+)\)\=:E631:/
    endtry
endfunction

function! json#jqplay#run(mods, bang, start_line, end_line, jq_filter) abort
    if a:jq_filter =~# '-h\>\|--help\>'
        echo system(s:get('exe') .. ' --help')
        return
    endif

    let jq_cmd = printf('%s %s %s', s:get('exe'), s:get('opts'), a:jq_filter)

    if a:bang
        let b:jqinfo = {
                \ 'start_line': a:start_line,
                \ 'end_line': a:end_line,
                \ 'cmd': jq_cmd
                \ }
        let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'execute') . '| unlet! b:jqinfo'
        call json#jqplay#bang#filter(a:start_line, a:end_line, s:get('maxindent'), jq_cmd)
    else
        let in_buf = bufnr('%')
        let out_name = 'jq-output://' . expand('%:p')
        let out_buf = s:json_scratch(out_name, a:mods)

        call setbufvar(out_buf, 'jqinfo', {
                \ 'start_line': a:start_line,
                \ 'end_line': a:end_line,
                \ 'in_buf':  in_buf,
                \ 'cmd': jq_cmd
                \ })
        let undo = getbufvar(out_buf, 'undo_ftplugin', 'execute') . '| unlet! b:jqinfo'
        call setbufvar(out_buf, 'undo_ftplugin', undo)

        if s:get('async')
            call json#jqplay#job#filter(in_buf, a:start_line, a:end_line, out_buf, jq_cmd)
        else
            call json#jqplay#system#filter(in_buf, a:start_line, a:end_line, out_buf, jq_cmd)
        endif
    endif
endfunction

function! json#jqplay#stop(...) abort
    if exists('g:jq_job')
        return job_stop(g:jq_job, a:0 ? a:1 : 'term')
    endif
endfunction

function! json#jqplay#stophow(arglead, cmdline, cursorpos) abort
    return join(['term', 'hup', 'quit', 'int', 'kill'], "\n")
endfunction

function! json#jqplay#complete(arglead, cmdline, cursorpos) abort
    if a:arglead[0] ==# '-' || a:cmdline =~# '.*Jq\s\+$'
        return filter(
                \ copy(['-a', '-C', '-c', '-e', '-f', '-h', '-j', '-L', '-M',
                \ '-n', '-R', '-r', '-S', '-s', '--arg', '--argfile', '--argjson',
                \ '--args', '--ascii-output', '--exit-status', '--from-file',
                \ '--color-output', '--compact-output', '--help', '--indent',
                \ '--join-output', '--jsonargs', '--monochrome-output',
                \ '--null-input', '--raw-input', '--raw-output', '--run-tests',
                \ '--seq', '--slurp', '--slurpfile', '--sort-keys', '--stream',
                \ '--tab', '--unbuffered', '--version']),
                \ 'stridx(v:val, a:arglead) == 0')
    else
        return map(getcompletion(a:arglead, 'file'), 'fnameescape(v:val)')
    endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
