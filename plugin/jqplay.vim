vim9script
# ==============================================================================
# Run jq interactively in Vim
# File:         plugin/jqplay.vim
# Author:       bfrg <https://github.com/bfrg>
# Website:      https://github.com/bfrg/vim-jqplay
# Last Change:  Dec 13, 2022
# License:      Same as Vim itself (see :h license)
# ==============================================================================

if exists('g:loaded_jqplay')
    finish
endif
g:loaded_jqplay = 1

import autoload '../autoload/jqplay.vim'

command -nargs=* -complete=customlist,jqplay.Complete Jqplay jqplay.Start(<q-mods>, <q-args>, bufnr())
command -nargs=* -complete=customlist,jqplay.Complete JqplayScratch jqplay.Scratch(true, <q-mods>, <q-args>)
command -nargs=* -complete=customlist,jqplay.Complete JqplayScratchNoInput jqplay.Scratch(false, <q-mods>, <q-args>)
