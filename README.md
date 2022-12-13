# vim-jqplay

Run [jq][jq] on a json buffer, and interactively update the output window
whenever the input buffer or the jq filter buffer are modified similar to
[jqplay.org][jqplay].

**Requirements:** Vim 9

<dl>
  <p align="center">
  <a href="https://asciinema.org/a/276970">
    <img src="https://asciinema.org/a/276970.png" width="480">
  </a>
  </p>
</dl>


## Usage

### Quick Overview

| Command                          | Description                                                                            |
| -------------------------------- | -------------------------------------------------------------------------------------- |
| `:Jqplay [{args}]`               | Start an interactive session using the current json buffer and a new jq script buffer. |
| `:JqplayScratch [{args}]`        | Like `:Jqplay` but creates a new scratch buffer as input.                              |
| `:JqplayScratchNoInput [{args}]` | Like `:JqplayScratch` but doesn't pass any input file to jq.                           |

### `:Jqplay`

Run `:Jqplay {args}` to start an interactive jq session using the current (json)
buffer as input and the jq options `{args}`. The command will open two new
windows:
1. The first window contains a jq scratch buffer (prefixed with `jq-filter://`)
   that is applied interactively to the current json buffer.
2. The second window displays the jq output (prefixed with `jq-output://`).

`{args}` can be any jq command-line options as you would pass them to jq in the
shell.

Jq is invoked automatically whenever the input buffer or the jq filter buffer
are modified. By default jq is executed when the `InsertLeave` or `TextChanged`
events are triggered. See [configuration](#configuration) below for how to
change the list of events when jq is invoked.

Once an interactive session is started the following commands are available:
* `:JqplayClose[!]` ─ Stop the interactive session. Add a `!` to also delete all
  associated scratch buffers.
* `:Jqrun [{args}]` ─ Invoke jq manually with the jq options `{args}`.
* `:Jqstop` ─ Terminate a running jq process started by this plugin.

Run `:Jqrun {args}` at any time to invoke jq manually with the jq arguments
`{args}` and the current `jq-filter://` buffer. This will temporarily override
the jq options previously set when starting the session with `:Jqplay {args}`.
Add a bang to `:Jqrun!` to permanently override the options for the
`jq-filter://` buffer.

`:Jqrun` is useful to quickly run the same jq filter with different set of jq
options, without closing the session. Alternatively, if you don't want to run jq
interactively on every buffer change, disable all autocommands and use `:Jqrun`
instead.

### `:JqplayScratch`

This command is like `:Jqplay` but starts an interactive jq session with a new
scratch buffer as input.

### `:JqplayScratchNoInput`

Opens an interactive session with a new jq filter buffer but without using any
input buffer. It always passes `-n/--null-input` to jq. This command is useful
when you don't need any input file passed to jq.


## Configuration

Options can be set through the dictionary variable `g:jqplay`. The following
entries are supported:

| Key        | Description                                                      | Default                          |
| ---------- | ---------------------------------------------------------------- | -------------------------------- |
| `exe`      | Path to jq executable.                                           | value found in `$PATH`           |
| `opts`     | Default jq command-line options (e.g. `--tab`).                  | -                                |
| `autocmds` | Events when jq is invoked.                                       | `['InsertLeave', 'TextChanged']` |
| `delay`    | Time in ms after which jq is invoked when an event is triggered. | `500`                            |

### Examples

1. Use the local jq executable, and tabs for indentation. Invoke jq whenever
   insert mode is left, or text is changed in either insert or normal mode.
   ```vim
   g:jqplay = {
       exe: '~/.local/bin/jq',
       opts: '--tab',
       autocmds: ['TextChanged', 'TextChangedI', 'InsertLeave']
   }
   ```
2. Use tabs for indentation, do not run jq automatically on buffer change.
   Instead invoke jq manually with `:Jqrun`:
   ```vim
   g:jqplay = {opts: '--tab', autocmds: []}
   ```


## Installation

```bash
$ cd ~/.vim/pack/git-plugins/start
$ git clone --depth=1 https://github.com/bfrg/vim-jqplay
$ vim -u NONE -c 'helptags vim-jqplay/doc | quit'
```
**Note:** The directory name `git-plugins` is arbitrary, you can pick any other
name. For more details see `:help packages`. Alternatively, use your favorite
plugin manager.


## Related plugins

[vim-jq][vim-jq] provides Vim runtime files like syntax highlighting for jq
script files.


## License

Distributed under the same terms as Vim itself. See `:help license`.

[jq]: https://github.com/stedolan/jq
[jqplay]: https://jqplay.org
[vim-jq]: https://github.com/bfrg/vim-jq
