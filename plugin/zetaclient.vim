"""Client library to interface with Zeta application via XMLRPC.

This module should not depend on any of the zeta modules.
"""

import xmlrpclib


class Client( object ) :
    """Interface class, instansiate one per server, this object will be
    utilized to make the actual xmlrpc calls and the result gets stuffed into
    the calling object which can be one among the,
            StaticWiki
            Project
            Wiki
            Ticket
            Review
    """

    def __init__( self, url ) :
        """`url` to server"""
        self.url    = url
        self.srvr   = xmlrpclib.Server( url )
        self.system = self.srvr.system

    def _marshalNone( self, val, default='None' ) :
        """`None` python data-type is not supported by XMLRPC, instead, it is
        marshalled as 'None' string"""
        if val == None :
            return default
        elif isinstance( val, list ) :
            newlist = []
            [ newlist.append( [ v, default ][ v == None ] ) for v in val ]
            return newlist
        else :
            return val

    def _demarshalNone( self, *args ) :
        """Interpret 'None' as None"""
        def translate( arg ) :
            if arg == 'None' :
                return None
            elif isinstance( arg, list ) :
                newlist = []
                [ newlist.append( [ l, None ][ l == 'None' ] ) for l in arg ]
                return newlist
            else :
                return arg

        if len(args) == 1 :
            return translate( args[0] )
        elif len(args) > 1 :
            return [ translate( arg ) for arg in args ]

    def _doexception( self, res ) :
        """To be called on the xmlrpc call's return value"""
        if res['rpcstatus'] == 'fail' :     # Call failed
            raise Exception( res['message'] )
        elif res['rpcstatus'] != 'ok' :     # Call did not succeed
            raise Exception( 'Returned rpcstatus not "ok" !' )
        return None

    def listMethods( self ) :
        """Built-in functions from xmlrpc object"""
        return self.system.listMethods()

    def methodHelp( self, methodName ) :
        """Built-in functions from xmlrpc object"""
        return self.system.methodHelp( methodName )

    def systementries( self ) :
        """Fetch the system entries"""
        res = self.srvr.system()
        self._doexception( res )
        return res['entries']

    def myprojects( self ) :
        """Get the list of projects, to which `user` is associated.
        Returns, list of Project objects"""
        res = self.srvr.myprojects()
        self._doexception( res )
        return [ Project( self, projname ) for projname in res['projectnames'] ]

    def projectdetails( self, p ) :
        """Do not call this method directly, instead use,
                projectobj.fetch()
        Returns back the Project object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( self, p )
        res = self.srvr.projectdetails( p.projectname )
        self._doexception( res )
        p.components   = res['components']
        p.milestones   = res['milestones']
        p.versions     = res['versions']
        p.projectusers = res['projectusers']
        return p

    def liststaticwikis( self ) :
        """Get the list of static wiki pages.
        Returns, list of StaticWiki objects"""
        res = self.srvr.liststaticwikis()
        self._doexception( res )
        return [ StaticWiki( self, path ) for path in res['paths'] ]
        
    def newstaticwiki( self, path, content ) :
        """Instansiate a new static wiki page with `content` under `path`
        On success returns StaticWiki object
        """
        res = self.srvr.newstaticwiki( path, content )
        self._doexception( res )
        return StaticWiki( self, path, text=content )

    def staticwiki( self, sw ) :
        """Do not call this method directly, instead use,
                staticwikiobj.fetch()
        Returns back the StaticWiki object
        """
        if isinstance( sw, (str, unicode) ) :
            sw = StaticWiki( self, sw )
        res = self.srvr.staticwiki( sw.path )
        self._doexception( res )
        sw.text     = res['text']
        sw.texthtml = res['texthtml']
        return sw
        
    def publishstaticwiki( self, sw, content ) :
        """Do not call this method directly, instead use,
                staticwikiobj.publish()
        Returns back the StaticWiki object
        """
        if isinstance( sw, (str, unicode) ) :
            sw = StaticWiki( self, sw )
        res = self.srvr.publishstaticwiki( sw.path, content )
        self._doexception( res )
        sw.text = content
        return sw

    def listwikipages( self, p ) :
        """Do not call this method directly, instead use,
                projectobj.fetchwikis()
        Returns a list of Wiki object, one of each wiki page under project `p`
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( self, p )
        res = self.srvr.listwikipages( p.projectname )
        self._doexception( res )
        return [ Wiki( self, p, pagename ) for pagename in res['wikipages'] ]

    def newwikipage( self, p, pagename, type='', summary='' ) :
        """Do not call this method directly, instead use,
                projectobj.newwiki()
        Returns a newly created Wiki object.
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( self, p )
        type    = self._marshalNone( type )
        summary = self._marshalNone( summary )
        res = self.srvr.newwikipage( p.projectname, pagename, type, summary )
        self._doexception( res )
        return Wiki( self, p, pagename, type=type, summary=summary )

    def wiki( self, p, w ) :
        """Do not call this method directly, instead use,
                wikiobj.fetch()
        Returns the Wiki object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( w, (str, unicode) ) :
            w = Wiki( self, p, w )
        res = self.srvr.wiki( p.projectname, w.pagename )
        self._doexception( res )
        w.type    = res['type']
        w.summary = self._demarshalNone( res['summary'] )
        w.text    = self._demarshalNone( res['text'] )
        w.projectname = p.projectname
        return w

    def publishwiki( self, p, w, content ) :
        """Do not call this method directly, instead use,
                wikiobj.publish()
        Returns the Wiki object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( self, p )
        if isinstance( w, (str, unicode) ) :
            w = Wiki( self, p, w )
        res = self.srvr.publishwiki( p.projectname, w.pagename, content )
        self._doexception( res )
        w.text = content
        return w

    def configwiki( self, p, w, type='', summary='' ) :
        """Do not call this method directly, instead use,
                wikiobj.config()
        Returns the Wiki object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( w, (str, unicode) ) :
            w = Wiki( self, p, w )
        type    = self._marshalNone( type )
        summary = self._marshalNone( summary )
        res = self.srvr.configwiki( p.projectname, w.pagename, type, summary )
        self._doexception( res )
        w.type    = type
        w.summary = summary
        return w

    def commentonwiki( self, p, w, comment ) :
        """Do not call this method directly, instead use,
                wikiobj.comment()
        Returns the Wiki object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( w, (str, unicode) ) :
            w = Wiki( self, p, w )
        res = self.srvr.commentonwiki( p.projectname, w.pagename, comment )
        self._doexception( res )
        return w

    def tagwiki( self, p, w, addtags=[], deltags=[] ) :
        """Do not call this method directly, instead use,
                wikiobj.addtags()
                wikiobj.deltags()
        Returns the Wiki object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( w, (str, unicode) ) :
            w = Wiki( self, p, w )
        addtags = self._marshalNone( addtags, [] )
        deltags = self._marshalNone( deltags, [] )
        res = self.srvr.tagwiki( p.projectname, w.pagename, addtags, deltags )
        self._doexception( res )
        return w

    def votewiki( self, p, w, vote ) :
        """Do not call this method directly, instead use,
                wikiobj.vote()
        Returns the Wiki object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( w, (str, unicode) ) :
            w = Wiki( self, p, w )
        res = self.srvr.votewiki( p.projectname, w.pagename, vote )
        self._doexception( res )
        return w

    def wikifav( self, p, w, favorite ) :
        """Do not call this method directly, instead use,
                wikiobj.favorite()
        Returns the Wiki object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( w, (str, unicode) ) :
            w = Wiki( self, p, w )
        res = self.srvr.wikifav( p.projectname, w.pagename, favorite )
        self._doexception( res )
        return w

    def listtickets( self, p ) :
        """Do not call this method directly, instead use,
                projectobj.fetchtickets()
        Returns the list of tickets under project
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        res = self.srvr.listtickets( p.projectname )
        self._doexception( res )
        tickets = []
        for tid in res['tickets'] :
            summary = res['tickets'][tid][0]
            tickets.append( Ticket( self, p, int(tid), summary=summary ))
        return tickets

    def newticket( self, p, summary, type, severity, description=u'',
                   components=[], milestones=[], versions=[],
                   blocking=[], blockedby=[], parent=None
                 ) :
        """Do not call this method directly, instead use,
                projectobj.newticket()
        Returns the newly created ticket
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        description = self._marshalNone( description )
        components  = self._marshalNone( components )
        milestones  = self._marshalNone( milestones )
        versions    = self._marshalNone( versions )
        blocking    = self._marshalNone( blocking )
        blockedby   = self._marshalNone( blockedby )
        parent      = self._marshalNone( parent )
        res = self.srvr.newticket(
                p.projectname, summary, type, severity, description,
                components, milestones, versions, blocking, blockedby, parent,
              )
        self._doexception( res )
        t = Ticket(
                self, p, res['id'],
                summary, type, severity, description=description,
                components=components, milestones=milestones, versions=versions,
                blocking=blocking, blockedby=blockedby, parent=parent
            )
        return t

    def ticket( self, p, t ) :
        """Do not call this method directly, instead use,
                ticketobj.fetch()
        Returns the Ticket object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( t, (int, long) ) :
            t = Ticket( self, p, t )
        res = self.srvr.ticket( p.projectname, t.id )
        self._doexception( res )
        res.pop( 'rpcstatus' )
        # De-Marshal 'None' to None
        for k in res :
            _i = self._demarshalNone( res[k] )
            res[k] = _i
        [ setattr( t, k, res[k] ) for k in res ]
        return t

    def configticket( self, p, t, **kwargs ) :
        """Do not call this method directly, instead use,
                ticketobj.config()
        Returns the Ticket object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( t, (int, long) ) :
            t = Ticket( self, p, t )

        res = self.srvr.configticket(
                    p.projectname, t.id,
                    self._marshalNone( kwargs.get( 'summary', None )),
                    self._marshalNone( kwargs.get( 'type', None )),
                    self._marshalNone( kwargs.get( 'severity', None )),
                    self._marshalNone( kwargs.get( 'description', None )),
                    self._marshalNone( kwargs.get( 'promptuser', None )),
                    self._marshalNone( kwargs.get( 'components', None )),
                    self._marshalNone( kwargs.get( 'milestones', None )),
                    self._marshalNone( kwargs.get( 'versions', None )),
                    self._marshalNone( kwargs.get( 'blocking', None )),
                    self._marshalNone( kwargs.get( 'blockedby', None )),
                    self._marshalNone( kwargs.get( 'parent', None )),
                    self._marshalNone( kwargs.get( 'status', None )),
                    self._marshalNone( kwargs.get( 'due_date', None ))
              )
        self._doexception( res )
        [ setattr( t, k, kwargs[k] ) for k in kwargs ]
        return t

    def commentonticket( self, p, t, comment ) :
        """Do not call this method directly, instead use,
                ticketobj.comment()
        Returns the Ticket object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( t, (int, long) ) :
            t = Ticket( self, p, t )
        res = self.srvr.commentonticket( p.projectname, t.id, comment )
        self._doexception( res )
        return t

    def tagticket( self, p, t, addtags=[], deltags=[] ) :
        """Do not call this method directly, instead use,
                ticketobj.addtags()
                ticketobj.deltags()
        Returns the Ticket object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( t, (int, long) ) :
            t = Ticket( self, p, t )
        addtags = self._marshalNone( addtags, [] )
        deltags = self._marshalNone( deltags, [] )
        res = self.srvr.tagticket( p.projectname, t.id, addtags, deltags )
        self._doexception( res )
        return t

    def voteticket( self, p, t, vote ) :
        """Do not call this method directly, instead use,
                ticketobj.vote()
        Returns the Ticket object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( t, (int, long) ) :
            t = Ticket( self, p, t )
        res = self.srvr.voteticket( p.projectname, t.id, vote )
        self._doexception( res )
        return t

    def ticketfav( self, p, t, favorite ) :
        """Do not call this method directly, instead use,
                ticketobj.favorite()
        Returns the Ticket object
        """
        if isinstance( p, (str, unicode) ) :
            p = Project( p )
        if isinstance( t, (int, long) ) :
            t = Ticket( self, p, t )
        res = self.srvr.ticketfav( p.projectname, t.id, favorite )
        self._doexception( res )
        return t


class StaticWiki( object ) :

    def __init__( self, client, path, text=None, texthtml=None ) :
        """Instansiate StaticWiki object"""
        self.client   = client
        self.path     = path
        self.text     = text
        self.texthtml = texthtml

    def fetch( self ) :
        """Fetch the contents of StaticWiki and return the content"""
        self.client.staticwiki( self )
        return self.text

    def publish( self, text ) :
        """Publish `text` as content for StaticWiki and return back the text"""
        self.client.publishstaticwiki( self, text )
        return self.text

    def __repr__( self ) :
        return self.path


class Project( object ) :

    def __init__( self, client, projectname ) :
        """Instansiate Project object"""
        self.client       = client
        self.projectname  = projectname
        self.components   = {}
        self.milestones   = {}
        self.vesions      = {}
        self.projectusers = {}
        self.wikis        = []
        self.tickets      = []

    def fetch( self ) :
        """Fetch project details"""
        return self.client.projectdetails( self )

    def fetchwikis( self ) :
        """Fetch list of wiki pages, as Wiki object list and return the same"""
        self.wikis   = self.client.listwikipages( self )
        return self.wikis

    def newwiki( self, pagename, type=None, summary=None ) :
        """Instansiate a new wiki-page and return the created Wiki object"""
        w = self.client.newwikipage(self, pagename, type=type, summary=summary)
        self.wikis.append( w )
        return w

    def fetchtickets( self ) :
        """Fetch list of tickets, as Ticket object and return the same"""
        self.tickets = self.client.listtickets( self )
        return self.tickets

    def newticket( self, summary, type, severity, **kwargs ) :
        """Instansiate a new ticket and return the created Ticket object"""
        t = self.client.newticket( self, summary, type, severity, **kwargs )
        self.tickets.append( t )
        return t

    def __repr__( self ) :
        return self.projectname


class Wiki( object ) :

    def __init__( self, client, project, pagename, type=None, summary=None ) :
        """Instansiate a Wiki object"""
        self.client   = client
        self.project  = project
        self.pagename = pagename
        self.type     = type
        self.summary  = summary
        self.projectname = project.projectname

    def fetch( self ) :
        """Fetch the wiki page and return back this object"""
        return self.client.wiki( self.project, self )

    def publish( self, text ) :
        """Publish `text` under wiki page and return back this object"""
        return self.client.publishwiki( self.project, self, text )

    def config( self, type=None, summary=None ) :
        """Configure wiki page and return back this object"""
        return self.client.configwiki(
                    self.project, self, type=type, summary=summary )

    def comment( self, comment ) :
        """Comment on wiki page and return back this object"""
        return self.client.commentonwiki( self.project, self, comment )

    def addtags( self, tags  ) :
        """Add tags to wiki page and return back this object"""
        return self.client.tagwiki( self.project, self, addtags=tags )

    def deltags( self, tags  ) :
        """Delete tags from wiki page and return back this object"""
        return self.client.tagwiki( self.project, self, deltags=tags )

    def vote( self, vote ) :
        """Vote for wiki page and return back this object"""
        return self.client.votewiki( self.project, self, vote )

    def favorite( self, favorite ) :
        """Add or remove wiki page as favorite and return back this object"""
        return self.client.wikifav( self.project, self, favorite )

    def __repr__( self ) :
        return self.pagename


class Ticket( object ) :

    def __init__( self, client, project, id,
                  summary=None, type=None, severity=None, description=None,
                  components=None, milestones=None, versions=None,
                  blocking=None, blockedby=None, parent=None
                ) :
        """Instansiate a Ticket object"""
        self.client      = client
        self.project     = project
        self.id          = id
        self.summary     = summary
        self.type        = type
        self.severity    = severity
        self.description = description
        self.components  = components
        self.milestones  = milestones
        self.versions    = versions
        self.blocking    = blocking
        self.blockedby   = blockedby
        self.parent      = parent

    def fetch( self ) :
        """Fetch ticket details and return back this object"""
        return self.client.ticket( self.project, self )

    def config( self, **kwargs ) :
        """Configure ticket and return back this object"""
        return self.client.configticket( self.project, self, **kwargs )

    def comment( self, comment ) :
        """Comment on ticket and return back this object"""
        return self.client.commentonticket( self.project, self, comment )

    def addtags( self, tags  ) :
        """Add tags to ticket and return back this object"""
        return self.client.tagticket( self.project, self, addtags=tags )

    def deltags( self, tags  ) :
        """Delete tags from ticket and return back this object"""
        return self.client.tagticket( self.project, self, deltags=tags )

    def vote( self, vote ) :
        """Vote for ticket and return back this object"""
        return self.client.voteticket( self.project, self, vote )

    def favorite( self, favorite ) :
        """Add or remove this ticket as favorite and return back this object"""
        return self.client.ticketfav( self.project, self, favorite )

    def __repr__( self ) :
        return str(self.id)
