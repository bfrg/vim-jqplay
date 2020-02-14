" ==============================================================================
" Run jq (the command-line JSON processor) interactively in Vim
" File:         autoload/jqplay.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  Feb 14, 2020
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

" Check order: b:jqplay -> g:jqplay -> s:defaults
let s:get = {k -> get(get(b:, 'jqplay', get(g:, 'jqplay', {})), k, get(s:defaults, k))}

" Helper function to create full jq command
let s:jqcmd = {exe, opts, args, file -> printf('%s %s %s -f %s', exe, opts, args, file)}

function! s:error(msg)
    echohl ErrorMsg | echomsg a:msg | echohl None
endfunction

function! s:new_scratch(bufname, filetype, clean, mods, ...) abort
    let winid = win_getid()

    if bufexists(a:bufname)
        let bufnr = bufnr(a:bufname)
        call setbufvar(bufnr, '&filetype', a:filetype)
        if a:clean
            silent call deletebufline(bufnr, 1, '$')
        endif

        if bufwinnr(bufnr) > 0
            return bufnr
        else
            silent execute a:mods 'keepalt sbuffer' bufnr
        endif
    else
        silent execute a:mods 'keepalt new' fnameescape(a:bufname)
        setlocal noswapfile buflisted buftype=nofile bufhidden=hide
        let bufnr = bufnr('%')
        call setbufvar(bufnr, '&filetype', a:filetype)
    endif

    if a:0
        execute 'resize' a:1
    endif
    call win_gotoid(winid)
    return bufnr
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
    if in_buf == -1
        call s:jq_job(s:jq_ctx, funcref('s:close_cb', [filter_buf]))
    else
        call s:jq_job(jq_ctx, funcref('s:close_cb_2', [in_buf, filter_buf]))
    endif
endfunction

function! s:filter_changed() abort
    let filter_buf = s:jq_ctx.filter_buf
    if getbufvar(filter_buf, 'jq_changedtick') == getbufvar(filter_buf, 'changedtick')
        return
    endif
    call writefile(getbufline(filter_buf, 1, '$'), s:jq_ctx.filter_file)
    call s:jq_job(s:jq_ctx, funcref('s:close_cb', [filter_buf]))
endfunction

function! s:input_changed() abort
    let in_buf = s:jq_ctx.in_buf
    if getbufvar(in_buf, 'jq_changedtick') == getbufvar(in_buf, 'changedtick')
        return
    endif
    call s:jq_job(s:jq_ctx, funcref('s:close_cb', [in_buf]))
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

    let opts = {
            \ 'in_io': 'null',
            \ 'out_cb': {_,msg -> appendbufline(a:jq_ctx.out_buf, '$', msg)},
            \ 'err_cb': {_,msg -> appendbufline(a:jq_ctx.out_buf, '$', '// ' .. msg)},
            \ 'close_cb': a:close_cb
            \ }

    if a:jq_ctx.in_buf != -1
        call extend(opts, {'in_io': 'buffer', 'in_buf': a:jq_ctx.in_buf})
    endif

    " https://github.com/vim/vim/issues/4688
    try
        let s:job = job_start([&shell, &shellcmdflag, a:jq_ctx.cmd], opts)
    catch /^Vim\%((\a\+)\)\=:E631:/
    endtry
endfunction

function! jqplay#start(mods, args, in_buf) abort
    if a:args =~# '-\a*f\>\|--from-file\>'
        return s:error('jqplay: -f and --from-file options not allowed')
    endif

    if s:jqplay_open
        return s:error('jqplay: only one session per Vim instance allowed')
    endif

    " Check if -r/--raw-output or -j/--join-output options are passed
    let out_ft = a:args =~# '\v-@1<!-\a*%(r|j)\a*|--%(raw|join)-output>' ? '' : 'json'

    " Output buffer
    let out_name = 'jq-output://' .. (a:in_buf == -1 ? '' : bufname(a:in_buf))
    let out_buf = s:new_scratch(out_name, out_ft, 1, a:mods)

    " jq filter buffer
    let filter_name = 'jq-filter://' .. (a:in_buf == -1 ? '' : bufname(a:in_buf))
    let filter_buf = s:new_scratch(filter_name, 'jq', 0, 'botright', 10)

    " Temporary file where jq filter buffer is written to
    let filter_file = tempname()

    let s:jq_ctx = {
            \ 'in_buf': a:in_buf,
            \ 'out_buf': out_buf,
            \ 'filter_buf': filter_buf,
            \ 'filter_file': filter_file,
            \ 'cmd': s:jqcmd(s:get('exe'), s:get('opts'), a:args, filter_file)
            \ }

    " When a:in_buf is set to -1, no input buffer will be passed to jq
    if a:in_buf != -1
        call setbufvar(a:in_buf, 'jq_changedtick', getbufvar(a:in_buf, 'changedtick'))
    endif
    call setbufvar(filter_buf, 'jq_changedtick', getbufvar(filter_buf, 'changedtick'))

    " When input, output or filter buffer are deleted/wiped out, close the
    " interactive session
    augroup jqplay
        autocmd!
        if a:in_buf != -1
            execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call jqplay#close(0)', a:in_buf)
        endif
        execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call jqplay#close(0)', out_buf)
        execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call jqplay#close(0)', filter_buf)
    augroup END

    " Run jq interactively when input or filter buffer are modified
    if !empty(s:get('autocmds'))
        let events = join(s:get('autocmds'), ',')
        if a:in_buf != -1
            execute printf('autocmd jqplay %s <buffer> call s:input_changed()', events)
        endif
        execute printf('autocmd jqplay %s <buffer=%d> call s:filter_changed()', events, filter_buf)
    endif

    execute 'command! -bar -bang JqplayClose call jqplay#close(<bang>0)'
    execute 'command! -bar -bang -nargs=? -complete=customlist,jqplay#complete Jqrun call s:run_manually(<bang>0, <q-args>)'
    execute 'command! -nargs=? -complete=custom,jqplay#stopcomplete Jqstop call jqplay#stop(<f-args>)'
    let s:jqplay_open = 1
endfunction

function! jqplay#scratch(bang, mods, args) abort
    let raw_input = a:args =~# '-\a*R\a*\>\|--raw-input\>' ? 1 : 0
    let null_input = a:args =~# '-\a*n\a*\>\|--null-input\>' ? 1 : 0

    if a:bang && raw_input && null_input
        return s:error('jqplay: not possible to run :JqplayScratch! with -n and -R')
    endif

    if !s:jqplay_open && !a:bang
        tabnew
        setlocal buflisted buftype=nofile bufhidden=hide noswapfile
        call setbufvar('%', '&filetype', raw_input ? '' : 'json')
    elseif !s:jqplay_open && a:bang
        tab split
    endif

    let args = a:bang && !null_input ? (a:args .. ' -n') : a:args
    let bufnr = a:bang ? -1 : bufnr('%')
    call jqplay#start(a:mods, args, bufnr)
    " Close the initial window that we opened with :tab split
    if a:bang
        close
    endif
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
        if s:jq_ctx.in_buf != -1 && getbufvar(s:jq_ctx.in_buf, '&buftype') ==# 'nofile'
            execute 'bdelete' s:jq_ctx.in_buf
        endif
    endif

    delcommand JqplayClose
    delcommand Jqrun
    delcommand Jqstop
    let s:jqplay_open = 0
    echohl WarningMsg | echomsg 'jqplay session closed' | echohl None
endfunction

function! jqplay#stop(...) abort
    return exists('s:job') ? job_stop(s:job, a:0 ? a:1 : 'term') : ''
endfunction

function! jqplay#ctx() abort
    return s:jqplay_open ? s:jq_ctx : {}
endfunction

function! jqplay#jq_job() abort
    return exists('s:job') ? s:job : ''
endfunction

function! jqplay#stopcomplete(arglead, cmdline, cursorpos) abort
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
                \ '--null-input', '--raw-input', '--raw-output', '--rawfile',
                \ '--run-tests', '--seq', '--slurp', '--slurpfile', '--sort-keys',
                \ '--stream', '--tab', '--unbuffered']),
                \ 'stridx(v:val, a:arglead) == 0')
    else
        return map(getcompletion(a:arglead, 'file'), 'fnameescape(v:val)')
    endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
