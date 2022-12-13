" ==============================================================================
" Run jq (the command-line JSON processor) interactively in Vim
" File:         autoload/jqplay.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  Aug 17, 2021
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:is_running = 0            " 1 if jqplay session running, 0 otherwise
let s:in_buf = -1               " Input buffer number (optional)
let s:in_changedtick = -1       " b:changedtick of input buffer (optional)
let s:in_timer = 0              " timer-ID of input buffer (optional)
let s:filter_buf = 0            " Filter buffer number
let s:filter_changedtick = 0    " b:changedtick of filter buffer
let s:filter_timer = 0          " timer-ID of filter buffer
let s:filter_file = ''          " Full path to filter file on disk
let s:out_buf = 0               " Output buffer number
let s:jq_cmd = ''               " jq command running on buffer change

const s:defaults = {
        \ 'exe': exepath('jq'),
        \ 'opts': '',
        \ 'delay': 500,
        \ 'autocmds': ['InsertLeave', 'TextChanged']
        \ }

const s:getopt = {k -> get(g:, 'jqplay', {})->get(k, s:defaults[k])}

" Helper function to create full jq command
const s:jqcmd = {exe, opts, args, file -> printf('%s %s %s -f %s', exe, opts, args, file)}

" Is jqplay session running with input buffer?
const s:jq_with_input = {-> s:in_buf != -1}

function s:error(...)
    echohl ErrorMsg | echomsg 'jqplay:' call('printf', a:000) | echohl None
endfunction

function s:warning(...)
    echohl WarningMsg | echomsg 'jqplay:' call('printf', a:000) | echohl None
endfunction

function s:new_scratch(bufname, filetype, clean, mods, ...) abort
    const winid = win_getid()

    if bufexists(a:bufname)
        const bufnr = bufnr(a:bufname)
        call setbufvar(bufnr, '&filetype', a:filetype)
        if a:clean
            silent call deletebufline(bufnr, 1, '$')
        endif

        if bufwinnr(bufnr) > 0
            return bufnr
        else
            silent execute a:mods 'sbuffer' bufnr
        endif
    else
        silent execute a:mods 'new' fnameescape(a:bufname)
        setlocal noswapfile buflisted buftype=nofile bufhidden=hide
        const bufnr = bufnr('%')
        call setbufvar(bufnr, '&filetype', a:filetype)
    endif

    if a:0
        execute 'resize' a:1
    endif
    call win_gotoid(winid)
    return bufnr
endfunction

function s:run_manually(bang, args) abort
    if a:args =~# '\%(^\|\s\)-\a*f\>\|--from-file\>'
        return s:error('-f and --from-file options not allowed')
    endif

    if s:filter_changedtick != getbufvar(s:filter_buf, 'changedtick')
        call getbufline(s:filter_buf, 1, '$')->writefile(s:filter_file)
    endif

    let jq_cmd = s:jqcmd(s:getopt('exe'), s:getopt('opts'), a:args, s:filter_file)
    call s:run_jq(jq_cmd)

    if a:bang
        let s:jq_cmd = jq_cmd
    endif
endfunction

function s:on_filter_changed() abort
    if s:filter_changedtick == getbufvar(s:filter_buf, 'changedtick')
        return
    endif

    let s:filter_changedtick = getbufvar(s:filter_buf, 'changedtick')
    call timer_stop(s:filter_timer)
    let s:filter_timer = s:getopt('delay')->timer_start(funcref('s:filter_changed'))
endfunction

function s:filter_changed(...) abort
    call getbufline(s:filter_buf, 1, '$')->writefile(s:filter_file)
    call s:run_jq(s:jq_cmd)
endfunction

function s:on_input_changed() abort
    if s:in_changedtick == getbufvar(s:in_buf, 'changedtick')
        return
    endif

    let s:in_changedtick = getbufvar(s:in_buf, 'changedtick')
    call timer_stop(s:in_timer)
    let s:in_timer = s:getopt('delay')->timer_start({_ -> s:run_jq(s:jq_cmd)})
endfunction

function s:close_cb(channel) abort
    silent call deletebufline(s:out_buf, 1)
    redrawstatus!
endfunction

function s:run_jq(jq_cmd) abort
    silent call deletebufline(s:out_buf, 1, '$')

    if exists('s:job') && job_status(s:job) ==# 'run'
        call job_stop(s:job)
    endif

    let opts = {
            \ 'in_io': 'null',
            \ 'out_cb': {_,msg -> appendbufline(s:out_buf, '$', msg)},
            \ 'err_cb': {_,msg -> appendbufline(s:out_buf, '$', '// ' .. msg)},
            \ 'close_cb': funcref('s:close_cb')
            \ }

    if s:jq_with_input()
        call extend(opts, {'in_io': 'buffer', 'in_buf': s:in_buf})
    endif

    " https://github.com/vim/vim/issues/4688
    try
        let s:job = job_start([&shell, &shellcmdflag, a:jq_cmd], opts)
    catch /^Vim\%((\a\+)\)\=:E631:/
    endtry
endfunction

function s:jq_stop(...) abort
    return exists('s:job') ? job_stop(s:job, a:0 ? a:1 : 'term') : ''
endfunction

function s:jq_close(bang) abort
    if !s:is_running && !(exists('#jqplay#BufDelete') || exists('#jqplay#BufWipeout'))
        return
    endif

    call s:jq_stop()
    autocmd! jqplay

    if a:bang
        execute 'bwipeout' s:filter_buf
        execute 'bwipeout' s:out_buf
        if s:jq_with_input() && getbufvar(s:in_buf, '&buftype') ==# 'nofile'
            execute 'bwipeout' s:in_buf
        endif
    endif

    delcommand JqplayClose
    delcommand Jqrun
    delcommand Jqstop
    let s:is_running = 0
    call s:warning('jqplay interactive session closed')
endfunction

" When 'in_buf' is set to -1, no input buffer is passed to jq
function jqplay#start(mods, args, in_buf) abort
    if a:args =~# '\%(^\|\s\)-\a*f\>\|--from-file\>'
        return s:error('-f and --from-file options not allowed')
    endif

    if s:is_running
        return s:error('only one interactive session allowed')
    endif

    let s:is_running = 1
    let s:in_buf = a:in_buf

    " Check if -r/--raw-output or -j/--join-output options are passed
    const out_ft = a:args =~# '\%(^\|\s\)-\a*[rj]\a*\|--\%(raw\|join\)-output\>' ? '' : 'json'

    " Output buffer
    const out_name = 'jq-output://' .. (a:in_buf == -1 ? '' : bufname(a:in_buf))
    let s:out_buf = s:new_scratch(out_name, out_ft, 1, a:mods)

    " jq filter buffer
    const filter_name = 'jq-filter://' .. (a:in_buf == -1 ? '' : bufname(a:in_buf))
    let s:filter_buf = s:new_scratch(filter_name, 'jq', 0, 'botright', 10)

    " Temporary file where jq filter buffer is written to
    let s:filter_file = tempname()

    let s:in_changedtick = getbufvar(a:in_buf, 'changedtick', -1)
    let s:filter_changedtick = getbufvar(s:filter_buf, 'changedtick')
    let s:in_timer = 0
    let s:filter_timer = 0
    let s:jq_cmd = s:jqcmd(s:getopt('exe'), s:getopt('opts'), a:args, s:filter_file)

    " When input, output or filter buffer are deleted/wiped out, close the
    " interactive session
    augroup jqplay
        autocmd!
        if s:jq_with_input()
            execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call s:jq_close(0)', a:in_buf)
        endif
        execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call s:jq_close(0)', s:out_buf)
        execute printf('autocmd BufDelete,BufWipeout <buffer=%d> call s:jq_close(0)', s:filter_buf)
    augroup END

    " Run jq interactively when input or filter buffer are modified
    if !empty(s:getopt('autocmds'))
        const events = s:getopt('autocmds')->join(',')
        if s:jq_with_input()
            execute printf('autocmd jqplay %s <buffer> call s:on_input_changed()', events)
        endif
        execute printf('autocmd jqplay %s <buffer=%d> call s:on_filter_changed()', events, s:filter_buf)
    endif

    execute 'command -bar -bang JqplayClose call s:jq_close(<bang>0)'
    execute 'command -bar -bang -nargs=? -complete=customlist,jqplay#complete Jqrun call s:run_manually(<bang>0, <q-args>)'
    execute 'command -nargs=? -complete=custom,jqplay#stopcomplete Jqstop call s:jq_stop(<f-args>)'
endfunction

function jqplay#scratch(bang, mods, args) abort
    if s:is_running
        return s:error('only one interactive session allowed')
    endif

    if a:args =~# '\%(^\|\s\)-\a*f\>\|--from-file\>'
        return s:error('-f and --from-file options not allowed')
    endif

    const raw_input = a:args =~# '\%(^\|\s\)-\a*R\a*\>\|--raw-input\>'
    const null_input = a:args =~# '\%(^\|\s\)-\a*n\a*\>\|--null-input\>'

    if a:bang && raw_input && null_input
        return s:error('not possible to run :JqplayScratch! with -n and -R')
    endif

    if a:bang
        tab split
    else
        tabnew
        setlocal buflisted buftype=nofile bufhidden=hide noswapfile
        call setbufvar('%', '&filetype', raw_input ? '' : 'json')
    endif

    const args = a:bang && !null_input ? (a:args .. ' -n') : a:args
    const bufnr = a:bang ? -1 : bufnr('%')
    call jqplay#start(a:mods, args, bufnr)

    " Close the initial window that we opened with :tab split
    if a:bang
        close
    endif
endfunction

function jqplay#job() abort
    return exists('s:job') ? s:job : ''
endfunction

function jqplay#stopcomplete(arglead, cmdline, cursorpos) abort
    return join(['term', 'hup', 'quit', 'int', 'kill'], "\n")
endfunction

function jqplay#complete(arglead, cmdline, cursorpos) abort
    if a:arglead[0] ==# '-'
        return copy(['-a', '-C', '-c', '-e', '-f', '-h', '-j', '-L', '-M',
                \ '-n', '-R', '-r', '-S', '-s', '--arg', '--argfile', '--argjson',
                \ '--args', '--ascii-output', '--exit-status', '--from-file',
                \ '--color-output', '--compact-output', '--help', '--indent',
                \ '--join-output', '--jsonargs', '--monochrome-output',
                \ '--null-input', '--raw-input', '--raw-output', '--rawfile',
                \ '--run-tests', '--seq', '--slurp', '--slurpfile', '--sort-keys',
                \ '--stream', '--tab', '--unbuffered'])
                \ ->filter('stridx(v:val, a:arglead) == 0')
    endif
    return getcompletion(a:arglead, 'file')->map('fnameescape(v:val)')
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
