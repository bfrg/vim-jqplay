# vim-jqplay

1. Run [jq][jq] from Vim's `Command-line` on a json buffer and display the
   output in a new split window, or apply it to the input buffer directly, hence
   acting as a filter.

2. Alternatively, open a `jq` scratch buffer and apply it interactively on the
   input buffer while both the `jq` filter buffer or the `json` input buffer are
   being modified, similar to [jqplay.org][jqplay].


## Usage

### Run jq from Vim's Command-line mode

Run `:Jq {args}` on the current json buffer, where `{args}` are any `jq`
command-line arguments as you would write them in the shell. The output is
displayed in a new `split` window.

Run `:Jq! {args}` with a bang to replace the current json buffer with the output
of `jq`.

Both commands accept a `[range]`. In this case only the selected lines are
passed to `jq` as input. Trailing commas in the last line of the `[range]` are
removed automatically to avoid `jq` parsing errors, and for `:Jq!` put back
afterwards.

### Run jq interactively whenever input or filter buffer are modified

Run `:Jqplay {args}` on the current json buffer to open a new `jq` scratch
buffer and apply the edited filter interactively to the current buffer. `{args}`
can be any `jq` command-line arguments (except for the `-f` and `--from-file`
options).

The output is displayed in a separate `split` window similar to the `:Jq`
command. Jq runs interactively while both the json input buffer or the `jq`
scratch buffer are being modified, by default whenever the `InsertLeave` or
`TextChanged` event are triggered. See `:help jqplay-config` on how to change
the `autocmds`.

Running `:JqplayClose` will remove the autocommands and keep the `jq` scratch
buffer and the jq output buffer open. Running `:JqplayClose!` with a bang will
additionally delete both buffers.

`jq` processes previously started with `:Jq` or `:Jqplay` can be stopped at any
time with `:JqStop`.


## Configuration

Options like the path to the `jq` executable can be set in either the
buffer-variable `b:jqplay`, or the global-variable `g:jqplay`. See `:help
jqplay-config` for more details.


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
