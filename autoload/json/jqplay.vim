" ==============================================================================
" Integration of jq (the command-line JSON processor) into Vim
" File:         autoload/json/jqplay.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  Oct 19, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:defaults = {
        \ 'exe': exepath('jq'),
        \ 'opts': '--tab',
        \ 'async': 1,
        \ 'maxindent': 2048
        \ }

function! s:get(key) abort
    let jqplay = get(b:, 'jqplay', get(g:, 'jqplay', {}))
    return has_key(jqplay, a:key) ? get(jqplay, a:key) : get(s:defaults, a:key)
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
