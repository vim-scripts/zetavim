"""
[< <style type="text/css"> >]
h1, h2, h3, h4, h5 { 
    margin : 0px;
    padding: 5px 0px 2px 3px;
    background-color : #EAEAFC;
    border-bottom: 1px solid #CCCCCC;
}
[< </style> >]

{{ Toc( float='right' ) }}

h2. VimInterface

Use Vim editor to interface with a zeta site.

h2. VimCommands

All commands are available as Vim Ex-commands (commands that are executed
in '':'' mode). Zeta commands for vim are generally classified as,

* profile commands
* wiki commands
* ticket commands
* review commands
* guest-wiki commands

h3. Profiles

Create a profile for each server once, and subsequently use the profile for
connecting and interfacing with it. A profile typically consists of four
fields,
[<PRE 
    name     : <profile-name>
    server   : <server-ip>
    username : <login-user>
    password : <password-for-user>
>]

While inside the vim editor, users can create, list and clear site profiles.
Alternately, users can connect to zeta-site (without creating a profile first)
using the //Zconnect// command

h3. Guest-wiki pages

Once connected to the site, use Zeta-vim Ex commands to list, fetch, create
and update guest-wiki pages. Use //path-url// to identify the page that needs to
be fetched or created.

h3. Project-wiki pages

Set current project or pass the project along with the command to list, fetch,
create and edit project's wiki pages.

h3. Project-ticket pages

Set current project or pass the project along with the command to list, fetch,
create and edit project's tickets.

h2. Complete list of commands

"""

import os
from   os.path      import join, dirname, isfile
import re
import sys
import commands
from   hashlib      import sha1

try :
    import vim
except :
    pass

sys.path.insert( 0, join( os.environ.get( 'HOME' ), '.vim', 'plugin' ))

import zetaclient   as zc
import ztext

cmtbufname  = '/tmp/comment' 
profilefile = join( os.environ.get( 'HOME' ), '.zetaprof' )
isfile( profilefile ) or open( profilefile, 'w' ).write( '' )
profiles    = {}
doclist     = []

def _parse_csv( line ) :
    """Parse line for comma separated values"""
    vals = line and line.split( ',' ) or []
    vals = filter( None, [ v.strip(' \t') for v in vals ] )
    return vals

def _echo( message, hl=None ) :
    message = message.replace( '\n', ' ' ).replace( '"', "'" )
    vim.command( 'echo "%s"' % message )

def _echoerr( message ) :
    vim.command( 'echohl PluginErr' )
    vim.command( 'echo "%s"' % message )
    vim.command( 'echohl PluginMsg' )


### Decorator functions

def hlecho( f ) :
    """Decorator function to highlight echo messages"""
    def withfunc( *args, **kwargs ) :
        vim.command( 'echohl PluginMsg' )
        f( *args, **kwargs )
        vim.command( 'echohl None' )
    f.func_doc and doclist.append( f.func_doc )
    return withfunc

def withargs( f ) :
    """Decorator function to handle variable and key word arguments"""
    def withfunc( *args, **kwargs ) :
        vim.command( 'echohl PluginMsg' )
        nargs = int(vim.eval( 'a:0' ))
        vargs = [ a for a in args ] + \
                [ vim.eval( 'a:%s' % (i+1) ) for i in range( nargs ) ]
        f( *vargs, **kwargs )
        vim.command( 'echohl None' )
    f.func_doc and doclist.append( f.func_doc )
    return withfunc


### Manage profiles

def _zetaprofiles() :
    global profiles
    for l in open( profilefile ).readlines() :
        name, server, username, password = _parse_csv( l )
        profiles.setdefault( name, (name, server, username, password) )
    return profiles

def _listprofiles() :
    global profiles
    profiles = _zetaprofiles()
    return [ ', '.join( profiles[name] ) for name in profiles ]

def _lookupprofile( name=None, server=None ) :
    _zetaprofiles()
    if name :
        proftup = profiles.get( name, None )
    elif server :
        for name in profiles :
            if profiles[name][1] == server :
                proftup = profiles[name]
                break
        else :
            proftup = None
    return proftup

def _updateprofile( name, server, username, password ) :
    global profiles
    profiles.update({ name : (name, server, username, password) })
    cont = '\n'.join([ ', '.join( profiles[name] ) for name in profiles ])
    open( profilefile, 'w').write( cont )
    return profiles

def _clearprofiles() :
    global profiles
    profiles = {}
    open( profilefile, 'w' ).write( '' )
    return profiles

### Helper functions

bufnames = [ cmtbufname ]
def new_mainwindow( zitem, text, title ) :
    mwin = [ win for win in vim.windows if win.buffer.name not in bufnames ][0]
    vim.command( "1wincmd k" )
    vim.command( "setlocal buftype=nofile" )
    vim.command( "setlocal bufhidden=hide" )
    vim.command( "setlocal noswapfile" )
    mwin.buffer[:] = None                                   # Clear the buffer
    text = text.split( '\n' )
    # Gotcha, even after clearing the buffer seem to have an empty line left.
    if len(text) > 0 and text[0] :
        mwin.buffer[0] = text[0]
    [ mwin.buffer.append( l ) for l in text[1:] ]

def new_cmtwindow( zitem, comment='' ) :
    for win in vim.windows :
        if win.buffer.name == bufnames[0] :
            cwin = win
            vim.command( "wincmd j" )
            break
    else :
        vim.command( 'silent 4split %s' % bufnames[0] )
        vim.command( "wincmd J" )
        vim.command( "4wincmd _" )
        cwin = vim.current.window
    vim.command( "setlocal buftype=nofile" )
    vim.command( "setlocal bufhidden=hide" )
    vim.command( "setlocal noswapfile" )
    cwin.buffer[:] == None                                  # Clear the buffer

def wiki2doc( wiki, attrs ) :
    # Notes : wiki.summary should not contain '\n' and the document content
    # should be in string format.
    wiki.summary = wiki.summary.replace( '\n', ' ' ).replace( '\n', ' ' )
    doc = '\n'.join([ '  %12s : %s' % ( attr, str(getattr( wiki, attr )))
                      for attr in attrs ])

    doc += '\n\n' + wiki.text
    return doc

def ticket2doc( t, attrs ) :
    # Notes : ticket.summary should not contain '\n' and the document content
    # should be in string format.
    t.summary = t.summary.replace( '\n', ' ' ).replace( '\n', ' ' )
    lines = []
    for attr in attrs :
        if attr == 'components' :
            val = getattr( t, 'compid', '' )
            val = val or ''
        elif attr == 'milestones' :
            val = getattr( t, 'mstnid', '' )
            val = val or ''
        elif attr == 'versions' :
            val = getattr( t, 'verid', '' )
            val = val or ''
        elif attr == 'ticketid' :
            val = getattr( t, 'id', '' )
            val = val or ''
        elif attr == 'due_date' :
            val = getattr( t, 'due_date', '' )
            val = val or ''
        elif attr == 'promptuser' :
            val = getattr( t, 'promptuser', '' )
            val = val or ''
        elif attr == 'parent' :
            val = getattr( t, 'parent', '' )
            val = val or ''
        else :
            val = getattr( t, attr, '' )

        if isinstance( val, list ) :
            val = ', '.join([ str(v) for v in val ])

        lines.append( '  %15s : %s' % (attr, str(val)) )
        doc = '\n'.join( lines )

    doc += '\n\n' + t.description
    return doc

def buffer2comment() :
    return '\n'.join([ line for line in vim.current.buffer[:] ])

### Helper functions to actually interface with Server

currprof   = None     # Current active profile [ name, server, username, pass ]
c          = None     # Client() instance
sysentries = {}       # Sysentries obtained from the server

projects   = {}
staticwikis= {}

zetaitem   = None

def _listsw( doecho=True, force=True ) :
    global staticwikis
    if force or staticwikis == {} :
        doecho and _echo( "Fetching static wiki pages from `%s` ..." % currprof[1] )
        staticwikis = dict([ (sw.path, sw) for sw in c.liststaticwikis() ])
    return staticwikis

def _myprojects( doecho=True, force=True ) :
    global projects
    if force or projects == {} :
        doecho and _echo( "Fetching project list from `%s` for `%s` ..." % currprof[1:3] )
        projects = dict([ (p.projectname, p) for p in c.myprojects() ])
    return projects

def _systementries( doecho=True, force=True ) :
    global sysentries
    if force or sysentries == {} :
        doecho and _echo( "Fetching system entries from `%s` ..." % currprof[1] )
        sysentries = c.systementries()
        sysentries['wikitypes'] = _parse_csv( sysentries['wikitypes'] )
    return sysentries

### Command completion

def _filterco( begintext, list ) :
    return [ l for l in list if l[:len(begintext)] == begintext ]

def complete_project( partial, lead ) :
    options = sorted( _myprojects( doecho=False, force=False ).keys() )
    if partial :
        options = _filterco( lead, options )
    return '\n'.join(options)

def complete_gwpath( partial, lead ) :
    options = sorted( _listsw(doecho=False, force=False).keys() )
    if partial :
        options = _filterco( lead, options )
    return '\n'.join(options)

def complete_wikipage( wikipages, partial, lead ) :
    options = sorted( wikipages )
    if partial :
        options = _filterco( lead, options )
    return '\n'.join(options)

def complete_ticket( tids, partial, lead ) :
    options    = [ str(tid) for tid in sorted([ int(tid) for tid in tids ]) ]
    if partial :
        options = _filterco( lead, options )
    return '\n'.join(options)

def complete_tcktype( partial, lead ) :
    sysentries = _systementries( doecho=False, force=False )
    options    = sorted( sysentries['tickettypes'] )
    if partial :
        options = _filterco( lead, options )
    return '\n'.join(options)

def complete_tckseverity( partial, lead ) :
    sysentries = _systementries( doecho=False, force=False )
    options    = sorted( sysentries['ticketseverity'] )
    if partial :
        options = _filterco( lead, options )
    return '\n'.join(options)

@withargs
def comp_options( cmd, arglead, cmdline, cursorpos  ) :
    res = ''
    partial = cmdline[-1] != ' '
    parts   = filter( None, cmdline.split(' ') )
    if cmd in [ 'Zlwiki', 'Zlticket' ] :
        res = complete_project( cmdline[-1] != ' ', arglead )

    elif cmd == 'Znewwiki' :
        offset  = (partial and len(parts)-1 or len(parts)) - 1
        compfns = [ complete_project, None, complete_wikitype ]
        func    = (offset >= 0 and offset < 3) and compfns[offset] or None
        res     = func and func( partial, arglead ) or ''

    elif cmd == 'Znewtck' :
        offset  = (partial and len(parts)-1 or len(parts)) - 1
        compfns = [ complete_project, complete_tcktype, complete_tckseverity ]
        func    = (offset >= 0 and offset < 3) and compfns[offset] or None
        res     = func and func( partial, arglead ) or ''

    elif cmd == 'Zfetchgw' :
        offset  = (partial and len(parts)-1 or len(parts)) - 1
        compfns = [ complete_gwpath ]
        func    = (offset >= 0 and offset < 1) and compfns[offset] or None
        res     = func and func( partial, arglead ) or ''

    elif cmd == 'Zfetchwiki' :
        projectname = vim.eval( 'g:projectname' ) 
        projects    = _myprojects( doecho=False, force=False )
        p           = projects.get( projectname, None )
        if p :
            wikis   = p.wikis or p.fetchwikis()
            offset  = (partial and len(parts)-1 or len(parts)) - 1
            compfns = [ complete_wikipage ]
            func    = (offset >= 0 and offset < 1) and compfns[offset] or None
            res     = func and func( [ w.pagename for w in wikis ],
                                     partial,
                                     arglead
                               ) or ''
        else :
            res = ''

    elif cmd == 'Zfetchtck' :
        projectname = vim.eval( 'g:projectname' ) 
        projects    = _myprojects( doecho=False, force=False )
        p           = projects.get( projectname, None )
        if p :
            tickets = p.tickets or p.fetchtickets()
            offset  = (partial and len(parts)-1 or len(parts)) - 1
            compfns = [ complete_ticket ]
            func    = (offset >= 0 and offset < 1) and compfns[offset] or None
            res     = func and func( [ t.id for t in tickets ],
                                     partial,
                                     arglead
                               ) or ''

    vim.command('let g:ZCompOptions = "%s"' % res )


### Commands

@withargs
def addprofile( name, server, username, password ) :
    """
    === Profile commands

    ==== Add a new profile for a zeta site

    > [<PRE Zaddprofile name [ server username password ] >]

    :name     :: profile name
    :server   :: server url, eg: http://sandbox.devwhiz.net/xmlrpc
    :username :: registered user in `server`
    :password :: user password

    """
    _updateprofile( name, server, username, sha1( password ).hexdigest() )
    _echo( "Added profile `%s`" % name )


@hlecho
def listprofiles() :
    """
    ==== List all the profiles accessible by this client.

    > [<PRE Zlistprofile >]

    print as list of tuples, like, 
    [< PRE name, server, username, password >]
    """
    for profstr in _listprofiles() :
        vim.command( 'echo "%s"' % profstr )


@hlecho
def clearprofiles() :
    """
    ==== Clear all the profiles previously created for this client.

    > [<PRE Zclearprofiles >]

    clear all profiles for this client.
    """
    _clearprofiles()


@withargs
def connect( server=None, username=None, password=None ) : 
    """
    ==== Connect with a server (zeta site) using a profile

    > [<PRE Zconnect <name|server> [username] [password] >]

    where,

    :name ::
        profile-name or server-url to connect with. For this to
        work, already a profile must be created either by that profile name or
        for the server url.
    :server & username & password ::
        Alternately connect directly to the `server` using username:password,
        without creating a profile
    """
    global currprof, c, sysentries

    proftup = _lookupprofile( name=server )
    proftup = proftup or _lookupprofile( server=server )

    # Try to interface with the server
    if proftup :
        currprof = proftup
        _echo( "Interface with server `%s` as user `%s` ..." % (proftup[1:3]))
        name, server, username, password = proftup
        url = "%s?username=%s&password=%s" % (server, username, password)
        c   = zc.Client( url )
        sysentries = _systementries()
        _listsw()
        _myprojects()
        vim.command( "setlocal buftype=nofile" )
        vim.command( "setlocal bufhidden=hide" )
        vim.command( "setlocal noswapfile" )
    else :
        _echo( "Invalid `%s` !!" % server )


@withargs
def listprojects() :
    """
    ==== List member projects

    > [<PRE Zlprojects >]

    List of all project in which user participates.
    """
    projects = _myprojects( doecho=False )
    [ _echo( "    %s" % projects[p].projectname ) for p in projects ]


@withargs
def listgw() :
    """
    === Guest-Wiki commands

    ==== List guest wiki pages

    > [<PRE Zlgw >]

    List all guest-wiki pages available under connected site.
    """
    staticwikis = _listsw() 
    [ _echo( sw.path ) for sw in staticwikis.values() ]


@withargs
def newgw( url ) :
    """
    ==== Create new guest wiki page

    > [<PRE Znewgw url >]

    Create a new guest wiki page under //url//, must be full path name.
    """
    global zetaitem
    sw       = c.newstaticwiki( unicode(url), u'' )
    zetaitem = sw
    new_mainwindow( sw, u'', sw.path )


@withargs
def fetchgw( url ) :
    """
    ==== Fetch guest wiki page

    > [<PRE Zfetchgw url >]

    Fetch guest wiki page into vim. Once fetched, its content is available for
    editing.
    """
    global zetaitem
    staticwikis = _listsw( force=False )
    sw          = staticwikis.get( url, None )
    if sw :
        zetaitem = sw
        sw.fetch()
        new_mainwindow( sw, sw.text, sw.path )
    else :
        _echoerr( "Invalid static wiki path, `%s`" % url )


@withargs
def listwiki( projectname=None ) :
    """
    === Project-Wiki commands

    ==== List project wiki pages

    > [<PRE Zlwiki projectname >]

    List all wiki pages under project //projectname//
    """
    projects    = _myprojects( doecho=False )
    projectname = projectname or vim.eval( 'g:projectname' ) 
    
    if projectname in projects.keys() :
        p = projects[projectname]
        _echo( "Fetching wiki page list for project `%s` ..." % projectname )
        [ _echo( "    %s" % w.pagename ) for w in p.fetchwikis() ]

    else :
        _echoerr( "Invalid projectname `%s` !!" % projectname )


@withargs
def newwiki( projectname, pagename, *args ) :
    """
    ==== Create a wiki page

    > [<PRE Znewwiki <projectname> <pagename> [type] [summary] >]

    : projectname :: Create the wiki page for this //projectname//
    : pagename    :: Wiki page name
    : type        :: Optional wiki page type
    : summary     :: Optional wiki page summary
    """
    global zetaitem
    projects   = _myprojects( doecho=False, force=False )
    sysentries = _systementries( doecho=False, force=False )
    p          = projects.get( projectname, None )
    if p :
        args       = list(args)
        type       = (args and (args[0] in sysentries['wikitypes']) and args.pop(0))\
                     or sysentries['def_wikitype']
        summary    = args and ' '.join( args ).replace( '\n', ' ' ) or ''
        wiki       = p.newwiki( unicode(pagename), unicode(type), unicode(summary) )
        zetaitem   = wiki
        wiki.fetch()
        doccontent = wiki2doc(
                        wiki,
                        [ 'type', 'summary', 'pagename', 'projectname' ]
                     )
        new_mainwindow( wiki, doccontent, wiki.pagename )
    else :
        _echoerr( "Invalid projectname `%s` !!" % projectname )


@withargs
def fetchwiki( pagename, projectname=None ) :
    """
    ==== Fetch project's wiki page

    > [<PRE Zfetchwiki pagename [projectname] >]

    Fetch the contents of wiki page //pagename// for project //projectname//.
    Once fetched and available in vim window, it is available for editing.
    """
    global zetaitem
    projectname = projectname or vim.eval( 'g:projectname' ) 
    projects    = _myprojects( doecho=False, force=False )
    p           = projects.get( projectname, None )
    if p :
        wikis = p.wikis or p.fetchwikis()
        for wiki in wikis :
            if wiki.pagename == pagename :
                wiki.fetch()
                zetaitem = wiki
                doccontent = wiki2doc(
                                wiki,
                                [ 'type', 'summary', 'pagename', 'projectname' ]
                             )
                new_mainwindow( wiki, doccontent, wiki.pagename )
                break;
        else :
            _echoerr( "Invalid wikipage `%s` for project `%s` !!" % (pagename, projectname) )
    else :
        _echoerr( "Set g:projectname to valid project !!" )


@withargs
def listticket( projectname=None ) :
    """
    === Project-Ticket commands

    ==== List project tickets

    > [<PRE Zlticket [projectname] >]

    List all the tickets (by its id) under project //projectname//.
    """
    projects    = _myprojects( doecho=False )
    projectname = projectname or vim.eval( 'g:projectname' ) 

    if projectname in projects.keys() :
        p = projects[projectname]
        _echo( "Fetching ticket list for project `%s` ..." % projectname )
        [ _echo( "    %6s %s ..." % (t.id, t.summary[:70] )) 
          for t in sorted( p.fetchtickets(), key=lambda t : t.id ) ]

    else :
        _echoerr( "Invalid projectname `%s` !!" % projectname )


@withargs
def newtck( projectname, type, severity, *args ) :
    """
    ==== Create a new ticket

    > [<PRE Znewtck <projectname> <type> <severity> <summary> >]
    
    Create a new ticket for project //projectname//. //type//, //severity//
    and //summary// attributes of the ticket are mandatory.
    """
    global zetaitem
    projects   = _myprojects( doecho=False, force=False )
    sysentries = _systementries( doecho=False, force=False )
    p          = projects.get( projectname, None )
    if p :
        summary    = args and ' '.join( args ).replace( '\n', ' ' ) or None
        ticket     = p.newticket( summary, type, severity )
        zetaitem   = ticket
        ticket.fetch()
        attrs      = [ 'ticketid', 'summary', 'type', 'severity', 'status',
                       'due_date', 'promptuser', 'blockedby',
                       'blocking', 'parent', 
                     ]
        doccontent = ticket2doc( ticket, attrs )
        new_mainwindow( ticket, doccontent, str(ticket.id) )
    else :
        _echoerr( "Invalid projectname `%s` !!" % projectname )


@withargs
def fetchticket( tid, projectname=None ) :
    """
    ==== Fetch a project ticket

    > [<PRE Zfetchtck id [projectname] >]

    Fetch ticket by its //id// for project //projectname//
    """
    global zetaitem
    projectname = projectname or vim.eval( 'g:projectname' ) 
    projects    = _myprojects( doecho=False, force=False )
    p           = projects.get( projectname, None )
    if p :
        tickets = p.tickets or p.fetchtickets()
        for ticket in tickets :
            if ticket.id == int(tid) :
                ticket.fetch()
                zetaitem   = ticket
                attrs      = [ 'ticketid', 'summary', 'type', 'severity', 'status',
                               'due_date', 'promptuser', 'components', 'milestones',
                               'versions', 'blocking', 'blockedby', 'parent', 
                             ]
                doccontent = ticket2doc( ticket, attrs )
                new_mainwindow( ticket, doccontent, str(ticket.id) )


@withargs
def addtags( *args ) :
    """
    === Common commands to wiki, ticket and review

    ==== Add tags

    > [<PRE Zatags tagname,tagname,tagname,... >]

    Based on the resource opened in the current window, like a wiki page or ticket,
    the resource will be tagged with tagnames
    """
    if isinstance( zetaitem, zc.Wiki ) or isinstance( zetaitem, zc.Ticket ) :
        tags = _parse_csv( ', '.join( args ) )
        zetaitem.addtags( tags )
    else :
        _echoerr( "Cannot tag `%s`" % zetaitem )
            

@withargs
def deltags( *args ) :
    """
    ==== Delete tags

    > [<PRE Zdtags tagname,tagname,tagname,... >]

    Based on the resource opened in the current window, like a wiki page or ticket,
    tagnames (if present) will be removed from the resource
    """
    if isinstance( zetaitem, zc.Wiki ) or isinstance( zetaitem, zc.Ticket ) :
        tags = _parse_csv( ', '.join( args ) )
        zetaitem.deltags( tags )
    else :
        _echoerr( "Cannot remove tags from `%s`" % zetaitem )
            

@withargs
def vote( voteas ) :
    """
    ==== Vote ticket or wiki page

    > [<PRE Zvote <up|down> >]

    Based on the resource opened in the current window, like a wiki page or ticket,
    up-vote (//up//) or down-vote the resource (//down//)
    """
    if isinstance( zetaitem, zc.Wiki ) or isinstance( zetaitem, zc.Ticket ) :
        zetaitem.vote( voteas )
    else :
        _echoerr( "Cannot vote `%s`" % zetaitem )


@withargs
def fav() :
    """
    ==== Favorite wiki page or ticket

    > [<PRE Zfav >]

    Based on the resource opened in the current window, like a wiki page or ticket,
    mark the resource a favorite or remove the resource from your favorite
    list.
    """
    if isinstance( zetaitem, zc.Wiki ) or isinstance( zetaitem, zc.Ticket ) :
        zetaitem.favorite( True )
    else :
        _echoerr( "Cannot add `%s` as favorite" % zetaitem )


@withargs
def nofav() :
    """
    ==== Remove Favorite wiki page or ticket

    > [<PRE Znofav >]

    Based on the resource opened in the current window, like a wiki page or ticket,
    mark the resource a favorite or remove the resource from your favorite
    list.
    """
    if isinstance( zetaitem, zc.Wiki ) or isinstance( zetaitem, zc.Ticket ) :
        zetaitem.favorite( False )
    else :
        _echoerr( "Cannot remove `%s` from favorite" % zetaitem )


@hlecho
def comment() :
    """
    ==== Comments to wiki or ticket page

    > [<PRE Zcmt >]

    Based on the resource opened in the current window, like a wiki page or ticket,
    comment on it.
    """
    if isinstance( zetaitem, zc.Wiki ) or isinstance( zetaitem, zc.Ticket ) :
        new_cmtwindow( zetaitem )
    else :
        _echoerr( "Cannot comment `%s`" % zetaitem )


def writeupdate() :

    bufname = vim.current.buffer.name

    if isinstance( zetaitem, zc.StaticWiki ) :
        text = '\n'.join( vim.current.buffer[:] )
        zetaitem.publish( text )

    elif isinstance( zetaitem, zc.Wiki ) and bufname == cmtbufname :
        zetaitem.comment( buffer2comment() )

    elif isinstance( zetaitem, zc.Wiki ) :
        text = '\n'.join( vim.current.buffer[:] )
        ctxt = ztext.parse( text )
        if isinstance( ctxt, ztext.Context ) and ctxt.strt.type == 'wiki' :
            dataset     = ctxt.strt.dataset
            type        = dataset.get( 'type', None )
            summary     = dataset.get( 'summary', None )
            pagename    = dataset.get( 'pagename', None )
            projectname = dataset.get( 'projectname', None )
            if type != None or summary != None :
                zetaitem.config( type=type, summary=summary )
            text = dataset.get( ctxt.strt.bodyname, '' )
            if (zetaitem.pagename != pagename) or (zetaitem.projectname != projectname) :
                _echoerr( "Please do not modify pagename / projectname" )
            else :
                zetaitem.publish( text )
        else :
            _echoerr( ctxt )

    elif isinstance( zetaitem, zc.Ticket ) and bufname == cmtbufname :
        zetaitem.comment( buffer2comment() )

    elif isinstance( zetaitem, zc.Ticket ) :
        text = '\n'.join( vim.current.buffer[:] )
        ctxt = ztext.parse( text )
        if isinstance( ctxt, ztext.Context ) and ctxt.strt.type == 'ticket' :
            dataset     = ctxt.strt.dataset
            ticketid    = dataset.get( 'ticket' )
            summary     = dataset.get( 'summary' )
            type        = dataset.get( 'type' )
            severity    = dataset.get( 'severity' )
            promptuser  = dataset.get( 'promptuser', None )
            components  = dataset.get( 'components', None )
            milestones  = dataset.get( 'milestones', None )
            versions    = dataset.get( 'versions', None )
            blocking    = dataset.get( 'blocking', None )
            blockedby   = dataset.get( 'blockedby', None )
            parent      = dataset.get( 'parent', None )
            status      = dataset.get( 'status' )
            due_date    = dataset.get( 'duedate', None )
            description = dataset.get( ctxt.strt.bodyname, '' )
            if zetaitem.id != ticketid :
                _echoerr( "Please do not modify id" )

            else :
                zetaitem.config(
                    summary=summary, type=type, severity=severity,
                    description=description, promptuser=promptuser,
                    components=components, milestones=milestones, versions=versions,
                    blocking=blocking, blockedby=blockedby, parent=parent,
                    status=status, due_date=due_date
                )

        else :
            _echoerr( ctxt )

    else :
        _echoerr( "Cannot write `%s`" % zetaitem )
