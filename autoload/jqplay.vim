vim9script
# ==============================================================================
# Run jq interactively in Vim
# File:         autoload/jqplay.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-jqplay
# Last Change:  Dec 13, 2022
# License:      Same as Vim itself (see :h license)
# ==============================================================================

var is_running: bool = false        # true if jqplay session running, false otherwise
var in_buf: number = -1             # input buffer number (optional)
var in_changedtick: number = -1     # b:changedtick of input buffer (optional)
var in_timer: number = 0            # timer-ID of input buffer (optional)
var filter_buf: number = 0          # filter buffer number
var filter_changedtick: number = 0  # b:changedtick of filter buffer
var filter_timer: number = 0        # timer-ID of filter buffer
var filter_file: string = ''        # full path to filter file on disk
var out_buf: number = 0             # output buffer number
var jq_cmd: string = ''             # jq command running on buffer change
var job_id: job                     # job object of jq process

const defaults: dict<any> = {
    exe: exepath('jq'),
    opts: '',
    delay: 500,
    autocmds: ['InsertLeave', 'TextChanged']
}

def Getopt(key: string): any
    return get(g:, 'jqplay', {})->get(key, defaults[key])
enddef

# Helper function to create full jq command
def Jqcmd(exe: string, opts: string, args: string, file: string): string
    return $'{exe} {opts} {args} -f {file}'
enddef

# Is jqplay session running with input buffer?
def Jq_with_input(): bool
    return in_buf != -1
enddef

def Error(msg: string)
    echohl ErrorMsg | echomsg '[jqplay]' msg | echohl None
enddef

def Warning(msg: string)
    echohl WarningMsg | echomsg '[jqplay]' msg | echohl None
enddef

def New_scratch(bufname: string, filetype: string, clean: bool, mods: string, opts: dict<any> = {}): number
    const winid: number = win_getid()
    var bufnr: number

    if bufexists(bufname)
        bufnr = bufnr(bufname)
        setbufvar(bufnr, '&filetype', filetype)
        if clean
            silent deletebufline(bufnr, 1, '$')
        endif

        if bufwinnr(bufnr) > 0
            return bufnr
        else
            silent execute mods 'sbuffer' bufnr
        endif
    else
        silent execute mods 'new' fnameescape(bufname)
        setlocal noswapfile buflisted buftype=nofile bufhidden=hide
        bufnr = bufnr()
        setbufvar(bufnr, '&filetype', filetype)
    endif

    if has_key(opts, 'resize')
        execute 'resize' opts.resize
    endif

    win_gotoid(winid)

    return bufnr
enddef

def Run_manually(bang: bool, args: string)
    if args =~ '\%(^\|\s\)-\a*f\>\|--from-file\>'
        Error('-f and --from-file options not allowed')
        return
    endif

    if filter_changedtick != getbufvar(filter_buf, 'changedtick')
        filter_buf->getbufline(1, '$')->writefile(filter_file)
    endif

    const cmd: string = Jqcmd(Getopt('exe'), Getopt('opts'), args, filter_file)
    Run_jq(cmd)

    if bang
        jq_cmd = cmd
    endif
enddef

def On_filter_changed()
    if filter_changedtick == getbufvar(filter_buf, 'changedtick')
        return
    endif

    filter_changedtick = getbufvar(filter_buf, 'changedtick')
    timer_stop(filter_timer)
    filter_timer = Getopt('delay')->timer_start(Filter_changed)
enddef

def Filter_changed(timer: number)
    filter_buf->getbufline(1, '$')->writefile(filter_file)
    Run_jq(jq_cmd)
enddef

def On_input_changed()
    if in_changedtick == getbufvar(in_buf, 'changedtick')
        return
    endif

    in_changedtick = getbufvar(in_buf, 'changedtick')
    timer_stop(in_timer)
    in_timer = Getopt('delay')->timer_start((_) => Run_jq(jq_cmd))
enddef

def Close_cb(ch: channel)
    silent deletebufline(out_buf, 1)
    redrawstatus!
enddef

def Run_jq(cmd: string)
    silent deletebufline(out_buf, 1, '$')

    if exists('job_id') && job_status(job_id) == 'run'
        job_stop(job_id)
    endif

    final opts: dict<any> = {
        in_io: 'null',
        out_cb: (_, msg: string) => appendbufline(out_buf, '$', msg),
        err_cb: (_, msg: string) => appendbufline(out_buf, '$', '// ' .. msg),
        close_cb: Close_cb
    }

    if Jq_with_input()
        extend(opts, {in_io: 'buffer', in_buf: in_buf})
    endif

    # http//github.com/vim/vim/issues/4688
    try
        job_id = job_start([&shell, &shellcmdflag, cmd], opts)
    catch /^Vim\%((\a\+)\)\=:E631:/
    endtry
enddef

def Jq_stop(arg: string = 'term')
    if job_status(job_id) == 'run'
        job_stop(job_id, arg)
    endif
enddef

def Jq_close(bang: bool)
    if !is_running && !(exists('#jqplay#BufDelete') || exists('#jqplay#BufWipeout'))
        return
    endif

    Jq_stop()
    autocmd_delete([{group: 'jqplay'}])

    if bang
        execute 'bwipeout' filter_buf
        execute 'bwipeout' out_buf
        if Jq_with_input() && getbufvar(in_buf, '&buftype') == 'nofile'
            execute 'bwipeout' in_buf
        endif
    endif

    delcommand JqplayClose
    delcommand Jqrun
    delcommand Jqstop
    is_running = false
    Warning('interactive session closed')
enddef

# When 'in_buffer' is set to -1, no input buffer is passed to jq
export def Start(mods: string, args: string, in_buffer: number)
    if args =~ '\%(^\|\s\)-\a*f\>\|--from-file\>'
        Error('-f and --from-file options not allowed')
        return
    endif

    if is_running
        Error('only one interactive session allowed')
        return
    endif

    is_running = true
    in_buf = in_buffer

    # Check if -r/--raw-output or -j/--join-output options are passed
    const out_ft: string = args =~ '\%(^\|\s\)-\a*[rj]\a*\|--\%(raw\|join\)-output\>' ? '' : 'json'

    # Output buffer
    const out_name: string = 'jq-output://' .. (in_buffer == -1 ? '' : bufname(in_buffer))
    out_buf = New_scratch(out_name, out_ft, true, mods)

    # jq filter buffer
    const filter_name: string = 'jq-filter://' .. (in_buffer == -1 ? '' : bufname(in_buffer))
    filter_buf = New_scratch(filter_name, 'jq', false, 'botright', {resize: 10})

    # Temporary file where jq filter buffer is written to
    filter_file = tempname()

    in_changedtick = getbufvar(in_buffer, 'changedtick', -1)
    filter_changedtick = getbufvar(filter_buf, 'changedtick')
    in_timer = 0
    filter_timer = 0
    jq_cmd = Jqcmd(Getopt('exe'), Getopt('opts'), args, filter_file)

    command -bar -bang JqplayClose Jq_close(<bang>false)
    command -bar -bang -nargs=? -complete=customlist,Complete Jqrun Run_manually(<bang>false, <q-args>)
    command -nargs=? -complete=custom,Stopcomplete Jqstop Jq_stop(<q-args>)

    # When input, output or filter buffer are deleted/wiped out, close the
    # interactive session
    autocmd_add([
        {
            group: 'jqplay',
            event: ['BufDelete', 'BufWipeout'],
            bufnr: out_buf,
            cmd: 'Jq_close(false)',
            replace: true
        },
        {
            group: 'jqplay',
            event: ['BufDelete', 'BufWipeout'],
            bufnr: filter_buf,
            cmd: 'Jq_close(false)',
            replace: true
        }
    ])

    if Jq_with_input()
        autocmd_add([{
            group: 'jqplay',
            event: ['BufDelete', 'BufWipeout'],
            bufnr: in_buffer,
            cmd: 'Jq_close(false)',
            replace: true
        }])
    endif

    # Run jq interactively when input or filter buffer are modified
    const events: list<string> = Getopt('autocmds')

    if !empty(events)
        return
    endif

    autocmd_add([{
        group: 'jqplay',
        event: events,
        bufnr: filter_buf,
        cmd: 'On_filter_changed()',
        replace: true
    }])

    if Jq_with_input()
        autocmd_add([{
            group: 'jqplay',
            event: events,
            bufnr: bufnr(),
            cmd: 'On_input_changed()',
            replace: true
        }])
    endif
enddef

export def Scratch(input: bool, mods: string, args: string)
    if is_running
        Error('only one interactive session allowed')
        return
    endif

    if args =~ '\%(^\|\s\)-\a*f\>\|--from-file\>'
        Error('-f and --from-file options not allowed')
        return
    endif

    const raw_input: bool = args =~ '\%(^\|\s\)-\a*R\a*\>\|--raw-input\>'
    const null_input: bool = args =~ '\%(^\|\s\)-\a*n\a*\>\|--null-input\>'

    if !input && raw_input && null_input
        Error('not possible to run :JqplayScratchNoInput with -n and -R')
        return
    endif

    if input
        tabnew
        setlocal buflisted buftype=nofile bufhidden=hide noswapfile
        if !raw_input
            setlocal filetype=json
        endif
    else
        tab split
    endif

    const arg: string = !input && !null_input ? (args .. ' -n') : args
    const bufnr: number = input ? bufnr() : -1
    Start(mods, arg, bufnr)

    # Close the initial window that we opened with :tab split
    if !input
        close
    endif
enddef

export def Job(): job
    return job_id
enddef

export def Stopcomplete(_, _, _): string
    return join(['term', 'hup', 'quit', 'int', 'kill'], "\n")
enddef

export def Complete(arglead: string, _, _): list<string>
    if arglead[0] == '-'
        return copy([
            '-a', '-C', '-c', '-e', '-f', '-h', '-j', '-L', '-M',
            '-n', '-R', '-r', '-S', '-s', '--arg', '--argfile', '--argjson',
            '--args', '--ascii-output', '--exit-status', '--from-file',
            '--color-output', '--compact-output', '--help', '--indent',
            '--join-output', '--jsonargs', '--monochrome-output',
            '--null-input', '--raw-input', '--raw-output', '--rawfile',
            '--run-tests', '--seq', '--slurp', '--slurpfile', '--sort-keys',
            '--stream', '--tab', '--unbuffered'
        ])
        ->filter((_, i: string): bool => stridx(i, arglead) == 0)
    endif

    return arglead
        ->getcompletion('file')
        ->map((_, i: string): string => fnameescape(i))
enddef
