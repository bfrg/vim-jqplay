# vim-jqplay

Run [jq][jq] on a json buffer, and interactively update the output window
whenever the input buffer or the jq filter buffer are modified similar to
[jqplay.org][jqplay].

<dl>
  <p align="center">
  <a href="https://asciinema.org/a/276970">
    <img src="https://asciinema.org/a/276970.png" width="480">
  </a>
  </p>
</dl>


## Usage

### Quick Overview

| Command                   | Description                                                         |
| ------------------------- | ------------------------------------------------------------------- |
| `:Jqplay [{args}]`        | Start an interactive session using the current json buffer and the jq options `{args}`.|
| `:JqplayScratch [{args}]` | Like `:Jqplay` but creates a new scratch buffer as input.           |
| `:JqplayScratch! [{args}]`| Like `:JqplayScratch` but forces `--null-input` and doesn't pass any input to `jq`.|
| `:Jqrun [{args}]`         | Invoke jq manually with the jq options `{args}`.                    |
| `:JqplayClose`            | Stop the _jqplay_ session.                                          |
| `:JqplayClose!`           | Stop the _jqplay_ session and delete all associated scratch buffers.|
| `:Jqstop`                 | Terminate a running jq process.                                     |

### Run jq automatically whenever input or filter buffer are modified

Running `:Jqplay {args}` on the current json buffer opens two new windows:
1. The first window contains a `jq` scratch buffer (prefixed with
   `jq-filter://`) that is applied interactively to the current json buffer.
2. The second window displays the `jq` output (prefixed with `jq-output://`).

`{args}` can be any `jq` command-line arguments as you would write them in the
shell (except for the `-f/--from-file` option and the filter).

Jq will run automatically whenever the input buffer or the `jq` filter buffer
are modified. By default `jq` is invoked when the `InsertLeave` or `TextChanged`
events are triggered. See [configuration](#configuration) below on how to change
the list of events.

**Note:** `:Jqplay` can be run only on json buffers, unless the
`-n/--null-input` and/or `-R/--raw-input` options have been passed.

If you want to start a _jqplay_ session with a new input buffer, run
`:JqplayScratch`. The command will open an interactive session in a new tab page
using a new scratch buffer as input. Running `:JqplayScratch!` with a bang will
force the `-n/--null-input` option and open an interactive session without using
any source buffer. This is useful when you don't need any input to be passed to
`jq`.

### Run jq manually on demand

Use `:Jqrun {args}` at any time to invoke `jq` manually with the `jq` arguments
`{args}` and the current `jq-filter://` buffer. This will temporarily override
the `jq` options previously set with `:Jqplay {args}`. Add a bang to `:Jqrun!`
to permanently override the options for the `jq-filter://` buffer.

`:Jqrun` is useful to quickly run the same `jq` script with different set of
`jq` arguments.

Alternatively, if you don't want to run `jq` interactively on every buffer
change, disable all autocommands and use `:Jqrun` instead.

**Note:** The command is available only after starting a _jqplay_ session with
`:Jqplay`, and is deleted after the session is closed.

### Close jqplay or stop a jq process

Running `:JqplayClose` will stop the interactive session. The `jq` filter
buffer and the output buffer will be kept open. Run `:JqplayClose!` with a bang
to stop the session and also delete the buffers. Think of `:JqplayClose!` as _I
am done, close everything!_

`jq` processes previously started with `:Jqplay` or `:Jqrun` can be stopped at
any time with `:Jqstop`.


## Configuration

Options are set in either the buffer-local dictionary `b:jqplay` (specified for
`json` filetypes), or the global dictionary `g:jqplay`. The following entries
can be set:

| Key        | Description                 | Default                          |
| ---------- | --------------------------- | -------------------------------- |
| `exe`      | Path to `jq` executable     | value found in `$PATH`           |
| `opts`     | Default `jq` arguments      | -                                |
| `autocmds` | Events when `jq` is invoked | `["InsertLeave", "TextChanged"]` |

If you don't want to run `jq` interactively on every buffer change, set
`autocmds` to an empty list and run `:Jqrun` manually.


## Examples

#### Example 1: `g:jqplay`

Use the local `jq` executable and tabs for indentation. Invoke `jq` whenever
insert mode is left, text is changed in normal mode, or when user doesn't press
a key in insert mode for the time specified with `updatetime`:
```vim
" in vimrc
let g:jqplay = {
    \ 'exe': '~/.local/bin/jq',
    \ 'opts': '--tab',
    \ 'autocmds': ['TextChanged', 'CursorHoldI', 'InsertLeave']
    \ }
```

#### Example 2: `b:jqplay`

Use tabs for indentation, do not run `jq` automatically on buffer change.
Instead invoke `jq` manually with `:Jqrun`:
```vim
" in after/ftplugin/json.vim
let b:jqplay = { 'opts': '--tab', 'autocmds': [] }
```


## Installation

#### Manual Installation

```bash
$ cd ~/.vim/pack/git-plugins/start
$ git clone https://github.com/bfrg/vim-jqplay
$ vim -u NONE -c "helptags vim-jqplay/doc" -c q
```
**Note:** The directory name `git-plugins` is arbitrary, you can pick any other
name. For more details see `:help packages`.

#### Plugin Managers

Assuming [vim-plug][plug] is your favorite plugin manager, add the following to
your `.vimrc`:
```vim
Plug 'bfrg/vim-jqplay'
```


## Related plugins

[vim-jq][vim-jq] provides Vim runtime files like syntax highlighting for `jq`
script files.


## License

Distributed under the same terms as Vim itself. See `:help license`.

[jq]: https://github.com/stedolan/jq
[jqplay]: https://jqplay.org
[plug]: https://github.com/junegunn/vim-plug
[vim-jq]: https://github.com/bfrg/vim-jq
