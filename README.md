# vim-jqplay

Run [jq][jq] on a json buffer, and interactively update the output window
whenever the input buffer or the jq filter buffer are modified, similar to
[jqplay.org][jqplay].


## Usage

#### Run jq automatically whenever input or filter buffer are modified

Running `:Jqplay {args}` on the current json buffer opens two new windows:
1. The first window contains a `jq` scratch buffer (prefixed with
   `jq-filter://`) that is applied interactively to the current json buffer.
2. The second window displays the `jq` output (prefixed with `jq-output://`).

`{args}` can be any `jq` command-line arguments as you would write them in the
shell (except for the `-f` and `--from-file` options, and the filter).

Jq will run automatically whenever the json input buffer or the `jq` filter
buffer are modified. By default `jq` is invoked when the `InsertLeave` or
`TextChanged` events are triggered. See `:help jqplay-config` or
[configuration][#Configuration] below on how to change the list of events.


#### Run jq manually on demand

Use `:Jqrun {args}` at any time to invoke `jq` manually with the `jq` arguments
`{args}` and the current `jq-filter://`. This will temporarily override the `jq`
options previously set with `:Jqplay {args}`. Add a `!` to `:Jqrun!` to
permanently override the options for the `jq` buffer.

`:Jqrun` is useful to quickly run the same `jq` script with different set of `jq`
arguments.

Alternatively, if you don't want to run `jq` interactively on every buffer
change, disable all autocommands and use `:Jqrun` instead.

#### Close jqplay or stop a jq process

Running `:JqplayClose` will stop the interactive session. The `jq` scratch
buffer and the output buffer will be kept open. Running `:JqplayClose!` with
a bang will stop the session and also delete both buffers. You can think of
`:JqplayClose!` as _I am done, close everything!_

`jq` processes previously started with `:Jqplay` or `:Jqrun` can be stopped at
any time with `:Jqstop`.


## Configuration

Options are set in either the buffer-local dictionary `b:jqplay`, or the
global dictionary `g:jqplay`.

**Note:** The buffer-variable `b:jqplay` needs to be specified for `json`
filetypes, for example, in `after/ftplugin/json.vim`

The following entries can be set:

| Key        | Description                 | Default                          |
| ---------- | --------------------------- | -------------------------------- |
| `exe`      | Path to `jq` executable     | value found in `$PATH`           |
| `opts`     | Default `jq` arguments      | ""                               |
| `autocmds` | Events when `jq` is invoked | `["InsertLeave", "TextChanged"]` |

If you don't want to run `jq` interactively on every buffer change, set
`autocmds` to an empty list and run `:Jqrun` manually.

See `:help jqplay-config` for more details.


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

#### Example 3: `:JqplayScratch`

`:Jqplay` is a buffer-local command available only in `json` buffers. If you
want to start a jqplay session from anywhere, add the following to your `vimrc`:

```vim
command! -nargs=? -complete=customlist,jqplay#complete JqplayScratch enew |
        \ setlocal buflisted buftype=nofile bufhidden=hide noswapfile filetype=json |
        \ <mods> Jqplay <args>
```
You can precede `:JqplayScratch` with a command modifier. For example, `:vert
JqplayScratch {args}` opens the `jq-output://` buffer in a new vertical split.


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
