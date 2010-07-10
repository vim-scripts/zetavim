" Plugin to interface with Zeta application via HTTP

" Check whether python bindings are available
if !has("python")
    finish
endif

" Import python modules
if filereadable($VIMRUNTIME."/plugin/zetavim.py")
  pyfile $VIMRUNTIME/plugin/zetavim.py
elseif filereadable($HOME."/.vim/plugin/zetavim.py")
  pyfile $HOME/.vim/plugin/zetavim.py
else
  call confirm('zeta.vim: Unable to find zetavim.py. Place it in the Vim runtime directory.', 'OK')
  finish
endif

let s:fullwinheight = winheight(0) 
let s:fullwinwidth  = winwidth(0) 

let fwh = s:fullwinheight
let fww = s:fullwinwidth
let g:projectname = ''
let type = ''

highlight PluginMsg ctermfg=green guifg=green
highlight PluginErr ctermfg=red guifg=red

"--------------------- Complete functions --------------------
function! CompList_Zlwiki(...)
    python comp_options( 'Zlwiki' )
    return g:ZCompOptions
endfunction

function! CompList_Zlticket(...)
    python comp_options( 'Zlticket' )
    return g:ZCompOptions
endfunction

function! CompList_Zfetchgw(...)
    python comp_options( 'Zfetchgw' )
    return g:ZCompOptions
endfunction

function! CompList_Zfetchwiki(...)
    python comp_options( 'Zfetchwiki' )
    return g:ZCompOptions
endfunction

function! CompList_Zfetchtck(...)
    python comp_options( 'Zfetchtck' )
    return g:ZCompOptions
endfunction

function! CompList_Znewwiki(...)
    python comp_options( 'Znewwiki' )
    return g:ZCompOptions
endfunction

function! CompList_Znewtck(...)
    python comp_options( 'Znewtck' )
    return g:ZCompOptions
endfunction

" Open and setup a window `name`, which can be 'main', 'comment'
function! ZWindow_open( name )
endfunction

" Close window `name`, which can be 'main', 'comment'
function! ZWindow_close( name )
endfunction

"------------------------ Commands - profile ---------------------------

" :Zprofile name server username password
"   Create a connection profile for a server
function! ZAddprofile(...)
    python addprofile()
endfunction
command! -nargs=* Zaddprofile call ZAddprofile(<f-args>)


" :Zlistprofile
"   Create a connect profile for a server
command! -nargs=0 Zlistprofiles python listprofiles()


" :Zclearprofiles
"   Create a connect profile for a server
command! -nargs=0 Zclearprofiles python clearprofiles()


" :Zconnect <name|server> [username] [password]
"   Connect to a server, will also setup the window for interfacing with Zeta
function! ZConnect(...)
    syn match docattr_pagename    "^  [ ]*pagename : .*$"
    syn match docattr_projectname "^  [ ]*projectname : .*$"
    syn match docattr_type        "^  [ ]*type : .*$"
    syn match docattr_summary     "^  [ ]*summary : .*$"
    syn match docattr_ticketid    "^  [ ]*ticketid : .*$"
    syn match docattr_severity    "^  [ ]*severity : .*$"
    syn match docattr_status      "^  [ ]*status : .*$"
    syn match docattr_due_date    "^  [ ]*due_date : .*$"
    syn match docattr_promptuser  "^  [ ]*promptuser : .*$"
    syn match docattr_components  "^  [ ]*components : .*$"
    syn match docattr_milestones  "^  [ ]*milestones : .*$"
    syn match docattr_versions    "^  [ ]*versions : .*$"
    syn match docattr_parent      "^  [ ]*parent : .*$"
    syn match docattr_blocking    "^  [ ]*blocking : .*$"
    syn match docattr_blockedby   "^  [ ]*blockedby : .*$"
    syn match docattr_text        "^Text : $"
    syn match docattr_description "^Description : $"
    hi def    docattr_pagename    ctermfg=green guifg=green
    hi def    docattr_projectname ctermfg=green guifg=green
    hi def    docattr_type        ctermfg=green guifg=green
    hi def    docattr_summary     ctermfg=green guifg=green
    hi def    docattr_ticketid    ctermfg=green guifg=green
    hi def    docattr_severity    ctermfg=green guifg=green
    hi def    docattr_status      ctermfg=green guifg=green
    hi def    docattr_due_date    ctermfg=green guifg=green
    hi def    docattr_promptuser  ctermfg=green guifg=green
    hi def    docattr_components  ctermfg=green guifg=green
    hi def    docattr_milestones  ctermfg=green guifg=green
    hi def    docattr_versions    ctermfg=green guifg=green
    hi def    docattr_parent      ctermfg=green guifg=green
    hi def    docattr_blocking    ctermfg=green guifg=green
    hi def    docattr_blockedby   ctermfg=green guifg=green
    hi def    docattr_text        ctermfg=green guifg=green
    hi def    docattr_description ctermfg=green guifg=green

    python connect()

    noremap! w<cr>    :python writeupdate()<cr>

endfunction
command! -nargs=* Zconnect call ZConnect(<f-args>)


" List projects
" args,
"   :Zlprojects
function! ZLprojects(...)
    python listprojects()
endfunction
command! -nargs=* Zlprojects  call ZLprojects(<f-args>)


" List static wiki pages
" args,
"   :Zlgw
function! ZLgw(...)
    python listgw()
endfunction
command! -nargs=0 Zlgw  call ZLgw(<f-args>)

" Create a new static wiki page
" args,
"   :Znewgw <url>
function! ZNewgw(...)
    python newgw()
endfunction
command! -nargs=1 Znewgw call ZNewgw(<f-args>)


" Fetch an existing static wiki page
" args,
"   :Zfetchgw url
function! ZFetchgw(...)
    python fetchgw()
endfunction
command! -nargs=1 -complete=custom,CompList_Zfetchgw Zfetchgw call ZFetchgw(<f-args>)


" List wiki pages
" args,
"   :Zlwiki [projectname]
function! ZLwiki(...)
    python listwiki()
endfunction
command! -nargs=? -complete=custom,CompList_Zlwiki Zlwiki  call ZLwiki(<f-args>)


" Create a new wiki page
" args,
"   :Znewwiki <projectname> <pagename> [type] [summary]
function! ZNewwiki(...)
    python newwiki()
endfunction
command! -nargs=* -complete=custom,CompList_Znewwiki Znewwiki call ZNewwiki(<f-args>)


" Fetch an existing wiki page
" args,
"   :Zfetchwiki pagename [projectname]
function! ZFetchwiki(...)
    python fetchwiki()
endfunction
command! -nargs=+ -complete=custom,CompList_Zfetchwiki Zfetchwiki call ZFetchwiki(<f-args>)


" List tickets
" args,
"   :Zlticket [projectname]
function! ZLticket(...)
    python listticket()
endfunction
command! -nargs=? -complete=custom,CompList_Zlticket Zlticket  call ZLticket(<f-args>)


" Fetch an ticket
" args,
"   :Zfetchtck id [projectname]
function! ZFetchtck(...)
    python fetchticket()
endfunction
command! -nargs=+ -complete=custom,CompList_Zfetchtck Zfetchtck call ZFetchtck(<f-args>)


" Create a new ticket
" args,
"   :Znewtck <projectname> <type> <severity> <summary>
function! ZNewtck(...)
    python newtck()
endfunction
command! -nargs=* -complete=custom,CompList_Znewtck Znewtck call ZNewtck(<f-args>)


" Add or delete tags from a wiki page, ticket
" args,
"   :Zatags [tagname,...]
"   :Zdtags [tagname,...]
function! ZATags(...)
    python addtags()
endfunction
function! ZDTags(...)
    python deltags()
endfunction
command! -nargs=* Zatags call ZATags(<f-args>)
command! -nargs=* Zdtags call ZDTags(<f-args>)


" Vote a wiki page, ticket
" args,
"   :Zvote [up|down]
function! ZVote(...)
    python vote()
endfunction
command! -nargs=1 Zvote call ZVote(<f-args>)


" Mark a wiki page, ticket as favorite
" args,
"   :Zfav 
"   :Znofav 
function! ZFav(...)
    python fav()
endfunction
function! ZNoFav(...)
    python nofav()
endfunction
command! -nargs=0 Zfav call ZFav()
command! -nargs=0 Znofav call ZNoFav()


" Comment on a wiki page, ticket
" args,
"   :Zcmt
command! -nargs=0 Zcmt python comment()
