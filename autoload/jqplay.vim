" ==============================================================================
" Run jq (the command-line JSON processor) interactively in Vim
" File:         autoload/jqplay.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  Oct 30, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

" Flag that indicates whether a jqplay session is running
let s:jqplay_open = 0

let s:defaults = {
        \ 'exe': exepath('jq'),
        \ 'opts': '',
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

function! s:new_scratch(bufname, filetype, mods, ...) abort
    " FIXME when jq-filter://foo.json is listed, bufnr('jq-filter://', 1) will
    " return bufnr of that buffer and won't create a new one!
    let bufnr = bufnr(a:bufname, 1)

    if bufwinnr(bufnr) == -1
        silent execute a:mods 'keepalt sbuffer' bufnr
        setlocal noswapfile buflisted buftype=nofile bufhidden=hide
        call setbufvar(bufnr, '&filetype', a:filetype)
        if a:0
            execute 'resize' a:1
        endif
        wincmd p
    endif

    silent call deletebufline(bufnr, 1, '$')
    return bufnr
endfunction

function! s:jqcmd(exe, opts, args, file) abort
    return printf('%s %s %s -f %s', a:exe, a:opts, a:args, a:file)
endfunction

function! jqplay#start(mods, args) abort
    if a:args =~# '-\a*f\>\|--from-file\>'
        return s:error('jqplay: -f and --from-file options not allowed')
    endif

    if s:jqplay_open
        return s:error('jqplay: only one session per Vim instance allowed')
    endif

    let raw_output = a:args =~# '-\a*r\a*\>\|--raw-output\>' ? 1 : 0
    let join_output = a:args =~# '-\a*j\a*\>\|--join-output\>' ? 1 : 0
    let out_ft = raw_output || join_output ? '' : 'json'
    let in_buf = bufnr('%')
    let out_name = 'jq-output://' . expand('%')
    let out_buf = s:new_scratch(out_name, out_ft, a:mods)
    let jqfilter_name = 'jq-filter://' . expand('%')
    let jqfilter_buf = s:new_scratch(jqfilter_name, 'jq', 'botright', 10)
    let jqfilter_file = tempname()
    let jq_cmd = s:jqcmd(s:get('exe'), s:get('opts'), a:args, jqfilter_file)

    let s:jq_ctx = {
            \ 'in_buf': in_buf,
            \ 'out_buf': out_buf,
            \ 'filter_buf': jqfilter_buf,
            \ 'filter_file': jqfilter_file,
            \ 'cmd': jq_cmd
            \ }

    " FIXME remove buffer-local variables when jqplay session is closed
    call setbufvar(in_buf, 'jq_changedtick', getbufvar(in_buf, 'changedtick'))
    call setbufvar(jqfilter_buf, 'jq_changedtick', getbufvar(jqfilter_buf, 'changedtick'))

    augroup jqplay
        autocmd!
        execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call jqplay#close(0)', in_buf)
        execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call jqplay#close(0)', out_buf)
        execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call jqplay#close(0)', jqfilter_buf)
    augroup END

    if !empty(s:get('autocmds'))
        let events = join(s:get('autocmds'), ',')
        execute printf('autocmd jqplay %s <buffer> call s:input_changed()', events)
        execute printf('autocmd jqplay %s <buffer=%d> call s:filter_changed()', events, jqfilter_buf)
    endif

    execute 'command! -bar -bang JqplayClose call jqplay#close(<bang>0)'
    execute 'command! -bar -bang -nargs=? -complete=customlist,jqplay#complete Jqrun call s:run_manually(<bang>0, <q-args>)'
    execute 'command! -nargs=? -complete=custom,jqplay#stophow Jqstop call jqplay#stop(<f-args>)'
    let s:jqplay_open = 1
endfunction

function! jqplay#scratch(mods, args)
    let raw_input = a:args =~# '-\a*R\a*\>\|--raw-input\>' ? 1 : 0
    if !s:jqplay_open
        tabnew
        setlocal buflisted buftype=nofile bufhidden=hide noswapfile
        call setbufvar('%', '&filetype', raw_input ? '' : 'json')
    endif
    call jqplay#start(a:mods, a:args)
endfunction

function! jqplay#ctx() abort
    return s:jqplay_open ? s:jq_ctx : {}
endfunction

function! jqplay#close(bang) abort
    if !s:jqplay_open && !(exists('#jqplay#BufDelete') || exists('#jqplay#BufWipeout'))
        return
    endif
    call jqplay#stop()
    autocmd! jqplay

    if a:bang
        execute 'bdelete' s:jq_ctx.filter_buf
        execute 'bdelete' s:jq_ctx.out_buf
        if getbufvar(s:jq_ctx.in_buf, '&buftype') ==# 'nofile'
            execute 'bdelete' s:jq_ctx.in_buf
        endif
    endif

    delcommand JqplayClose
    delcommand Jqrun
    delcommand Jqstop
    let s:jqplay_open = 0
    echohl WarningMsg | echomsg 'jqplay session closed' | echohl None
endfunction

function! s:run_manually(bang, args) abort
    if a:args =~# '-\a*f\>\|--from-file\>'
        return s:error('jqplay: -f and --from-file options not allowed')
    endif

    let in_buf = s:jq_ctx.in_buf
    let filter_buf = s:jq_ctx.filter_buf
    let filter_tick = getbufvar(filter_buf, 'jq_changedtick')

    if filter_tick != getbufvar(filter_buf, 'changedtick')
        call writefile(getbufline(filter_buf, 1, '$'), s:jq_ctx.filter_file)
    endif

    let jq_ctx = copy(s:jq_ctx)
    let jq_ctx.cmd = s:jqcmd(s:get('exe'), s:get('opts'), a:args, s:jq_ctx.filter_file)
    if a:bang
        let s:jq_ctx = jq_ctx
    endif
    call s:jq_job(jq_ctx, function('s:close_cb_2', [in_buf, filter_buf]))
endfunction

function! s:filter_changed() abort
    let filter_buf = s:jq_ctx.filter_buf
    if getbufvar(filter_buf, 'jq_changedtick') == getbufvar(filter_buf, 'changedtick')
        return
    endif
    call writefile(getbufline(filter_buf, 1, '$'), s:jq_ctx.filter_file)
    call s:jq_job(s:jq_ctx, function('s:close_cb', [filter_buf]))
endfunction

function! s:input_changed() abort
    let in_buf = s:jq_ctx.in_buf
    if getbufvar(in_buf, 'jq_changedtick') == getbufvar(in_buf, 'changedtick')
        return
    endif
    call s:jq_job(s:jq_ctx, function('s:close_cb', [in_buf]))
endfunction

function! s:close_cb(buf, channel) abort
    silent call deletebufline(s:jq_ctx.out_buf, 1)
    call setbufvar(a:buf, 'jq_changedtick', getbufvar(a:buf, 'changedtick'))
endfunction

function! s:close_cb_2(buf1, buf2, channel) abort
    silent call deletebufline(s:jq_ctx.out_buf, 1)
    call setbufvar(a:buf1, 'jq_changedtick', getbufvar(a:buf1, 'changedtick'))
    call setbufvar(a:buf2, 'jq_changedtick', getbufvar(a:buf2, 'changedtick'))
endfunction

function! s:jq_job(jq_ctx, close_cb) abort
    silent call deletebufline(a:jq_ctx.out_buf, 1, '$')

    if exists('s:job') && job_status(s:job) ==# 'run'
        call job_stop(s:job)
    endif

    " https://github.com/vim/vim/issues/4688
    " E631: write_buf_line(): write failed
    " This occurs only for large files
    try
        let s:job = job_start([&shell, &shellcmdflag, a:jq_ctx.cmd], {
                \ 'in_io': 'buffer',
                \ 'in_buf': a:jq_ctx.in_buf,
                \ 'out_cb': {_,msg -> appendbufline(a:jq_ctx.out_buf, '$', msg)},
                \ 'err_cb': {_,msg -> appendbufline(a:jq_ctx.out_buf, '$', '// ' . msg)},
                \ 'close_cb': a:close_cb
                \ })
    catch /^Vim\%((\a\+)\)\=:E631:/
    endtry
endfunction

function! jqplay#stop(...) abort
    return exists('s:job') ? job_stop(s:job, a:0 ? a:1 : 'term') : ''
endfunction

function! jqplay#jq_job() abort
    return exists('s:job') ? s:job : ''
endfunction

function! jqplay#stophow(arglead, cmdline, cursorpos) abort
    return join(['term', 'hup', 'quit', 'int', 'kill'], "\n")
endfunction

function! jqplay#complete(arglead, cmdline, cursorpos) abort
    if a:arglead[0] ==# '-'
        return filter(
                \ copy(['-a', '-C', '-c', '-e', '-f', '-h', '-j', '-L', '-M',
                \ '-n', '-R', '-r', '-S', '-s', '--arg', '--argfile', '--argjson',
                \ '--args', '--ascii-output', '--exit-status', '--from-file',
                \ '--color-output', '--compact-output', '--help', '--indent',
                \ '--join-output', '--jsonargs', '--monochrome-output',
                \ '--null-input', '--raw-input', '--raw-output', '--run-tests',
                \ '--seq', '--slurp', '--slurpfile', '--sort-keys', '--stream',
                \ '--tab', '--unbuffered']),
                \ 'stridx(v:val, a:arglead) == 0')
    else
        return map(getcompletion(a:arglead, 'file'), 'fnameescape(v:val)')
    endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
