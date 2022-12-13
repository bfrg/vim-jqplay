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

| Command                                   | Description                                                                                                         |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| <kbd>:Jqplay [{args}]</kbd>               | Start an interactive session using the current json buffer and a new jq filter buffer with the jq options `{args}`. |
| <kbd>:JqplayScratch [{args}]</kbd>        | Like <kbd>:Jqplay</kbd> but creates a new scratch buffer as input.                                                  |
| <kbd>:JqplayScratchNoInput [{args}]</kbd> | Like <kbd>:JqplayScratch</kbd> but doesn't pass any input file to jq.                                               |

### `:Jqplay`

Run <kbd>:Jqplay {args}</kbd> to start an interactive jq session using the
current (json) buffer as input and the jq options `{args}`. The command will
open two new windows:
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
* <kbd>:JqplayClose[!]</kbd> - Stop the interactive session. Add a `!` to also
  delete all associated scratch buffers.
* <kbd>:Jqrun [{args}]</kbd> - Invoke jq manually with the jq options `{args}`.
* <kbd>:Jqstop</kbd> - Terminate a running jq process started by this plugin.

Run <kbd>:Jqrun {args}</kbd> at any time to invoke jq manually with the jq
arguments `{args}` and the current `jq-filter://` buffer. This will temporarily
override the jq options previously set when starting the session with
<kbd>:Jqplay {args}</kbd>. Add a bang to <kbd>:Jqrun!</kbd> to permanently
override the options for the `jq-filter://` buffer.

<kbd>:Jqrun</kbd> is useful to quickly run the same jq filter with different set
of jq options, without closing the session. Alternatively, if you don't want to
run jq interactively on every buffer change, disable all autocommands and use
<kbd>:Jqrun</kbd> instead.

### `:JqplayScratch`

<kbd>:JqplayScratch</kbd> is like <kbd>:Jqplay</kbd> but starts an interactive
jq session with a new scratch buffer as input.

### `:JqplayScratchNoInput`

<kbd>:JqplayScratchNoInput</kbd> opens an interactive session without using any
input buffer and forces the `-n/--null-input` option. This is useful when you
don't need any input to be passed to jq.


## Configuration

Options can be set through the dictionary variable `g:jqplay`. The following
entries are supported:

| Key        | Description                                                      | Default                          |
| ---------- | ---------------------------------------------------------------- | -------------------------------- |
| `exe`      | Path to jq executable.                                           | value found in `$PATH`           |
| `opts`     | Default jq command-line options (like `--tab`).                  | -                                |
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
name. For more details see <kbd>:help packages</kbd>. Alternatively, use your
favorite plugin manager.


## Related plugins

[vim-jq][vim-jq] provides Vim runtime files like syntax highlighting for jq
script files.


## License

Distributed under the same terms as Vim itself. See <kbd>:help license</kbd>.

[jq]: https://github.com/stedolan/jq
[jqplay]: https://jqplay.org
[vim-jq]: https://github.com/bfrg/vim-jq
