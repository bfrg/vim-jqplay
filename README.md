# vim-jqplay

Run [jq][jq] from Vim's `Command-line` on a json buffer and display the output
in a new split window, or apply it to the input buffer in-place, hence acting as
a filter.


## Usage

Run `:Jq {args}` on the current json buffer, where `{args}` are any `jq`
command-line arguments as you would write them in the shell. The output is
displayed in a new `split` window.

Run `:Jq! {args}` with a bang to replace the current json buffer with the output
of `jq`.

Both commands accept a `[range]`. In this case only the selected lines are
passed to `jq` as input. Trailing commas in the last line of the `[range]` are
removed automatically to avoid `jq` parsing errors, and for `:Jq!` put back
afterwards.


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
[plug]: https://github.com/junegunn/vim-plug
[vim-jq]: https://github.com/bfrg/vim-jq
