vim9script
# ==============================================================================
# Run jq interactively in Vim
# File:         plugin/jqplay.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-jqplay
# Last Change:  Dec 24, 2023
# License:      Same as Vim itself (see :h license)
# ==============================================================================

import autoload '../autoload/jqplay.vim'

command -nargs=* -complete=customlist,jqplay.Complete Jqplay jqplay.Start(<q-mods>, <q-args>, bufnr())
command -nargs=* -complete=customlist,jqplay.Complete JqplayScratch jqplay.Scratch(true, <q-mods>, <q-args>)
command -nargs=* -complete=customlist,jqplay.Complete JqplayScratchNoInput jqplay.Scratch(false, <q-mods>, <q-args>)
