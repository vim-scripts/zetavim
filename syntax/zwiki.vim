" Vim syntax file
" Language:	Text based zwiki

" Quit when a (custom) syntax file was already loaded
"if exists("b:current_syntax")
"  finish
"endif

" Text Markup '' // __ ^^ ,, '/ /' '_ _' /_ _/ '/_ _/'
" Headings = == === ==== =====
"


" Simple markups
syn match escapechar         contained "\~"
syn match escapenewline      contained "\\\n"
syn match linebreak          contained "\\\\"

" URL
syn match plainweburl1       contained "http://[^ \t]\+"
syn match plainweburl2       contained "www\.[^ \t,]\+"

" Link
syn match plus               contained "+"
syn match star               contained "\*"
syn match dollar             contained "\$"
syn match http               contained "http:"
syn match mailto             contained "mailto:"
syn match linktext           contained "|[^\[\]]\+"
syn match wlink              contained "\[\[.*\]\]" contains=plus,star,dollar,mailto,http,linktext

" Text Markup
syn match tm_style           contained "{[^}]*}"
syn match textmarkup_1       contained "\('/_\|``\|''\|//\|__\|'/\|'_\|/_\)\({[^}]*}\)\?" contains=tm_style
syn match textmarkup_2       contained "_/'\|\^\^\|,,\|/'\|_'\|_/"

" HTML
syn match html               contained "\[<\_.\{-}>\]"

" Macros
syn match zwikimacro         contained "{{\_.\{-}}}"

" Heading
syn match headings           contained "^[ \t]*=\{1,5\}.*" contains=escapechar,escapenewline,linebreak,plainweburl1,plainweburl2,wlink,textmarkup_1,textmarkup_2

" Heading_alt
syn match headings_alt       contained "^[ \t]*h[12345]\..*" contains=escapechar,escapenewline,linebreak,plainweburl1,plainweburl2,wlink,textmarkup_1,textmarkup_2

" Horizontal Rule
syn match hrule              contained "-\{5,}"

" Ordered and Un-ordered List
syn match listmarkup         contained "^[ \t]*\*\{1,5}\|^[ \t]*#\{1,5}"
syn match list               contained "^[ \t]*\*\{1,5}\|^[ \t]*#\{1,5}.*" contains=listmarkup,escapechar,escapenewline,linebreak,plainweburl1,plainweburl2,wlink,textmarkup_1,textmarkup_2,html,zwikimacro

" Block Quoted text
syn match blockquote         contained "^[ \t]*>\{1,5}.*$" contains=escapechar,escapenewline,linebreak,plainweburl1,plainweburl2,wlink,textmarkup_1,textmarkup_2,html,zwikimacro

" Table
syn match st_style           contained "{[^}]*}"
syn match pipe               contained "|\({[^}]*}\)\?" contains=st_style
syn match pipeequal          contained "|=\({[^}]*}\)\?" contains=st_style
syn match tablemrkup         contained "\(^[ \t]*|=\|^[ \t]*|\).*" contains=pipe,pipeequal,escapechar,escapenewline,linebreak,plainweburl1,plainweburl2,wlink,textmarkup_1,textmarkup_2,html,zwikimacro

" Big table
syn match btablemrkup        contained "\(^[ \t]*||{\|||-\|||=\||| \|||}\)\({[^}]*}[ \t]*|\)\?" contains=st_style
 
" Definition
syn match definition         contained "[ \t]*:[^:]*::"

" Extensions
syn match zwikiext           contained "{{{\_.\{-}}}}"

syn match paragraph          "^.*$" contains=escapechar,escapenewline,linebreak,plainweburl1,plainweburl2,wlink,textmarkup_1,textmarkup_2,headings,headings_alt,hrule,list,blockquote,tablemrkup,btablemrkup,definition,html,zwikimacro,zwikiext

" cterm=bold ctermfg=LightGray  gui=bold guifg=#0000ff guibg=#0000ff
hi def tm_style         cterm=bold ctermfg=DarkGreen gui=bold guifg=DarkGreen
hi def textmarkup_1     cterm=bold ctermfg=Green gui=bold guifg=Green
hi def textmarkup_2     cterm=bold ctermfg=Green gui=bold guifg=Green
hi def plainweburl1     ctermfg=Magenta guifg=Magenta
hi def plainweburl2     ctermfg=Magenta guifg=Magenta
hi def headings         cterm=bold ctermfg=Yellow gui=bold guifg=Yellow
hi def headings_alt     cterm=bold ctermfg=Yellow gui=bold guifg=Yellow
hi def linebreak        cterm=bold ctermfg=Red gui=bold guifg=Red
hi def escapechar       cterm=bold ctermfg=Red gui=bold guifg=Red
hi def escapenewline    cterm=bold ctermfg=Red gui=bold guifg=Red
hi def plus             ctermfg=Red guifg=Red
hi def star             ctermfg=Red guifg=Red
hi def dollar           ctermfg=Red guifg=Red
hi def http             ctermfg=DarkMagenta guifg=DarkMagenta
hi def mailto           ctermfg=DarkMagenta guifg=DarkMagenta
hi def linktext         ctermfg=Gray guifg=Gray
hi def wlink            ctermfg=Magenta guifg=Magenta       
hi def hrule            ctermfg=Blue guifg=Blue
hi def listmarkup       ctermfg=Cyan guifg=Cyan
hi def blockquote       ctermfg=Gray guifg=Gray       
hi def st_style         ctermfg=DarkCyan guifg=DarkCyan       
hi def pipe             ctermfg=Cyan guifg=Cyan       
hi def pipeequal        ctermfg=Cyan guifg=Cyan       
hi def btablemrkup      ctermfg=Cyan guifg=Cyan       
hi def definition       cterm=bold gui=bold       
hi def html             ctermfg=Red guifg=Red       
hi def zwikimacro       ctermfg=Brown guifg=Brown       
hi def zwikiext         ctermfg=Gray guifg=Gray       

let b:current_syntax = "zwiki"

" vim: ts=8 sw=2
