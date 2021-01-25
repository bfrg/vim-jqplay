# vim-jqplay

Run [jq][jq] on a json buffer, and interactively update the output window
whenever the input buffer or the jq filter buffer are modified similar to
[jqplay.org][jqplay].

**Note:** Plugin requires Vim `>= 8.1.1776`.

<dl>
  <p align="center">
  <a href="https://asciinema.org/a/276970">
    <img src="https://asciinema.org/a/276970.png" width="480">
  </a>
  </p>
</dl>


## Usage

### Quick Overview

| Command                             | Description                                                                                |
| ----------------------------------- | ------------------------------------------------------------------------------------------ |
| <kbd>:Jqplay [{args}]</kbd>         | Start an interactive session using the current json buffer and the jq options `{args}`.    |
| <kbd>:JqplayScratch [{args}]</kbd>  | Like <kbd>:Jqplay</kbd> but creates a new scratch buffer as input.                         |
| <kbd>:JqplayScratch! [{args}]</kbd> | Like <kbd>:JqplayScratch</kbd> but forces `--null-input` and doesn't pass any input to jq. |

### `:Jqplay`

Run <kbd>:Jqplay {args}</kbd> to start an interactive jq session using the
current json buffer and the jq options `{args}`. The command will open two new
windows:
1. The first window contains a jq scratch buffer (prefixed with `jq-filter://`)
   that is applied interactively to the current json buffer.
2. The second window displays the jq output (prefixed with `jq-output://`).

`{args}` can be any jq command-line arguments as you would write them in the
shell (except for the `-f/--from-file` option and the filter).

Jq will be invoked automatically whenever the input buffer or the jq filter
buffer are modified. By default jq is invoked when the `InsertLeave` or
`TextChanged` events are triggered. See [configuration](#configuration) below
for how to change the list of events when jq is invoked.

Once an interactive session was started the following commands are available:
* <kbd>:JqplayClose[!]</kbd> - Stop the interactive session. Add a `!` to also
  delete all associated scratch buffers.
* <kbd>:Jqrun [{args}]</kbd> - Invoke jq manually with the jq options `{args}`.
* <kbd>:Jqstop</kbd> - Terminate a running jq process started by this plugin.

Run <kbd>:Jqrun {args}</kbd> at any time to invoke jq manually with the jq arguments
`{args}` and the current `jq-filter://` buffer. This will temporarily override
the jq options previously set when starting the session with <kbd>:Jqplay {args}</kbd>.
Add a bang to <kbd>:Jqrun!</kbd> to permanently override the options for the
`jq-filter://` buffer.

<kbd>:Jqrun</kbd> is useful to quickly run the same jq script with different set of jq
arguments. Alternatively, if you don't want to run jq interactively on every
buffer change, disable all autocommands and use <kbd>:Jqrun</kbd> instead.

### `:JqplayScratch`

Same as <kbd>:Jqplay</kbd> but start an interactive jq session with a new input
buffer. The command will open an interactive session in a new tab page using a
new scratch buffer as input. Running <kbd>:JqplayScratch!</kbd> with a bang will
force the `-n/--null-input` option and open an interactive session without using
any source buffer. This is useful when you don't need any input to be passed to
jq.


## Configuration

Options can be set through the dictionary variable `g:jqplay`. The following
entries are supported:

| Key        | Description                     | Default                          |
| ---------- | ------------------------------- | -------------------------------- |
| `exe`      | Path to jq executable           | value found in `$PATH`           |
| `opts`     | Default jq command-line options | -                                |
| `autocmds` | Events when jq is invoked       | `["InsertLeave", "TextChanged"]` |

If you don't want to run jq interactively on every buffer change, set `autocmds`
to an empty list and run <kbd>:Jqrun</kbd> manually.

### Examples

1. Use the local jq executable and tabs for indentation. Invoke jq whenever
   insert mode is left, text is changed in normal mode, or when user doesn't
   press a key in insert mode for the time specified with `updatetime`:
   ```vim
   let g:jqplay = {
       \ 'exe': '~/.local/bin/jq',
       \ 'opts': '--tab',
       \ 'autocmds': ['TextChanged', 'CursorHoldI', 'InsertLeave']
       \ }
   ```
2. Use tabs for indentation, do not run jq automatically on buffer change.
   Instead invoke jq manually with `:Jqrun`:
   ```vim
   let g:jqplay = {'opts': '--tab', 'autocmds': []}
   ```


## Installation

```bash
$ cd ~/.vim/pack/git-plugins/start
$ git clone https://github.com/bfrg/vim-jqplay
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
