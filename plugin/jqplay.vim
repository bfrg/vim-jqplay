" ==============================================================================
" Run jq (the command-line JSON processor) interactively in Vim
" File:         plugin/jqplay.vim
" Author:       bfrg <https://github.com/bfrg>
" Website:      https://github.com/bfrg/vim-jqplay
" Last Change:  Oct 29, 2019
" License:      Same as Vim itself (see :h license)
" ==============================================================================

if exists('g:loaded_jqplay')
    finish
endif
let g:loaded_jqplay = 1

let s:cpo_save = &cpoptions
set cpoptions&vim

command! -nargs=? -complete=customlist,jqplay#complete Jqplay call jqplay#start(<q-mods>, <q-args>)
command! -nargs=? -complete=customlist,jqplay#complete JqplayScratch call jqplay#scratch(<q-mods>, <q-args>)

let &cpoptions = s:cpo_save
unlet s:cpo_save
