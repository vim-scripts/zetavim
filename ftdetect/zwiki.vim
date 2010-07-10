" Vim syntax file
" Language:	Text based zwiki

" Quit when a (custom) syntax file was already loaded
"if exists("b:current_syntax")
"  finish
"endif

au BufRead,BufNewFile *.zwiki           set filetype=zwiki

" vim: ts=8 sw=2
