" ==============================================================================
" Integration of jq (the command-line JSON processor) into Vim
" File:         autoload/json/jq.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  July 25, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

function! s:json_scratch(bufname, mods) abort
    let l:out_buf = bufnr(a:bufname, 1)

    " Note: setting the filetype at last will allow users to override the other
    " buffer-local options in either after/ftplugin/json.vim, or using a
    " FileType autocommand
    " New buffers returned by bufnr({expr}, 1) are unloaded
    if !bufloaded(l:out_buf)
        call setbufvar(l:out_buf, '&swapfile', 0)
        call setbufvar(l:out_buf, '&buflisted', 1)
        call setbufvar(l:out_buf, '&buftype', 'nofile')
        call setbufvar(l:out_buf, '&bufhidden', 'hide')
        call setbufvar(l:out_buf, '&filetype', 'json')
    endif

    " Make sure buffer is visible
    if bufwinnr(l:out_buf) == -1
        silent execute a:mods 'keepalt sbuffer' fnameescape(a:bufname)
        wincmd p
    endif

    " Issue: https://github.com/vim/vim/issues/4718
    silent call deletebufline(l:out_buf, 1, '$')

    return l:out_buf
endfunction

function! json#jq#run(mods, bang, start_line, end_line, jq_filter) abort
    let l:jq_cmd = printf('%s %s %s',
            \ get(b:, 'jq_exe', exepath('jq')),
            \ get(b:, 'jq_opts', '-M'),
            \ a:jq_filter
            \ )

    " Quickly print help or version number
    if a:jq_filter =~# '-h\>\|--help\>'
        echo system(get(b:, 'jq_exe', exepath('jq')) . ' --help')
        return
    elseif a:jq_filter =~# '--version\>'
        echo system(get(b:, 'jq_exe', exepath('jq')) . ' --version')
        return
    endif

    if a:bang
        call json#jq#bang#filter(a:start_line, a:end_line, l:jq_cmd)
        let b:jq_cmd = l:jq_cmd
        let b:undo_ftplugin = get(b:, 'undo_ftplugin', '') . '| unlet! b:jq_cmd'
        let b:undo_ftplugin = substitute(b:undo_ftplugin, '^| ', '', '')
    else
        let l:in_buf = bufnr('%')
        let l:in_name = expand('%:p')
        let l:out_name = 'jq-output://' . expand('%:p')
        let l:out_buf = s:json_scratch(l:out_name, a:mods)

        call setbufvar(l:out_buf, 'jq', {
                \ 'start_line': a:start_line,
                \ 'end_line': a:end_line,
                \ 'file':  l:in_name,
                \ 'cmd': l:jq_cmd
                \ })
        let undo = getbufvar(l:out_buf, 'undo_ftplugin', '') . '| unlet! b:jq'
        call setbufvar(l:out_buf, 'undo_ftplugin', substitute(undo, '^| ', '', ''))

        if get(b:, 'jq_async', 1)
            call json#jq#job#filter(l:in_buf, a:start_line, a:end_line, l:out_buf, l:jq_cmd)
        else
            call json#jq#system#filter(l:in_buf, a:start_line, a:end_line, l:out_buf, l:jq_cmd)
        endif
    endif
endfunction

function! json#jq#complete(arglead, cmdline, cursorpos) abort
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
