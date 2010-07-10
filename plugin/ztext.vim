# This file is subject to the terms and conditions defined in
# file 'LICENSE', which is part of this source code package.
#       Copyright (c) 2009 SKR Farms (P) LTD.

"""Library to parse structured plain text into a dictionary consumable by zeta
Xinterface apis. This module should be self-standing and must not depend on
other zeta modules.

A note of terms,

head :
    Paragraph of lines, where each line will be parsed into (key, value) pairs
    that might get stuffed into `dataset`

delimiter :
    Delimiting line-pattern that seperates the head paragraph from text-body.
    This delimiter will further be used to name (`bodyname`) the text-body.

body :
    text-body, that will be consumed as is and will not be parsed for semantic
    meaning.

A note on member attributes,

dataset :
    Dictionary of parsed (key, value) pairs that can be sanitized and pushed
    into database.

bodyname :
    The `key` name in the (key, value) pair which will be used to stuff, the
    text-body into the dataset`

type :
    Type of the parsed text, if and when identified.

attributes :
    Dictionary of attributes, and a list of its expected incarnations in the
    (key, value) pairs.

mustattrss :
    List of possible combinations of attributes, if, when present in the parsed
    dataset, should be enough to identify the dataset for consumption.

hbdelimiter : 
    delimiter pattern seperating head and body, and can also be used to name
    body.

Email to text-block :
---------------------
* Email Subject will not be consumed.
* Trailing empty lines will be removed.
* All lines after the first EMAIL_ENDMARKER will be removed
* Trailing reply text will be removed. So that embedded reply comments will be
  retained.
"""

import re
try :
    import zeta.lib.helpers         as h
except :
    pass

class ZetaError( Exception ) :
    """Exception base class for errors in Zeta."""

    title = 'Zeta Error'
    
    def _get_message(self): 
        return self._message

    def _set_message(self, message): 
        self._message = message

    def __init__( self, message, title=None, show_traceback=False ):
        Exception.__init__( self, message )
        self.message   = message
        if title:
            self.title = title
        self.show_traceback = show_traceback

    def __unicode__( self ):
        return unicode( self.message )

    message = property(_get_message, _set_message)

class ZetaMailtextParse( ZetaError ) :
    """Handles all mail text parse error"""



EMAIL_ENDMARKER = '#end'

class FileC( object ) :
    def __init__( self, fcont='' ) :
        self.fcont = fcont
    def read( self ) :
        return self.fcont
    def close( self ) :
        return


def parse_csv( line ) :
    vals = line and line.split( ',' ) or []
    vals = filter( None, [ v.strip(' \t') for v in vals ] )
    return vals

def sanitizetags( tags ) :
    return [ unicode(tag) for tag in parse_csv(tags) if tag ]

def sanitizevalues( valstr ) :
    return [ int(e) for e in parse_csv( valstr ) if e ]

def sanitizebool( value ) :
    rvalue = None
    if value.lower() == 'true' :
        rvalue =  True
    elif value.lower() == 'false' :
        rvalue =  False
    return rvalue

def sanitizevote( value ) :
    rvalue = ''
    if value.lower() in [ 'up', 'down' ] :
        rvalue = value.lower()
    return unicode(rvalue)


class Structure( object ) :
    """Base class for all structurable text items, like,
            static-wiki,
            attachment,
            wiki,
            ticket,
            review

    Do not use this class directly, instead use it to derive other classes
    """

    def __init__( self ) :

        self.dataset  = {}      # Parsed data from text
        self.bodyname = None    # key, identifying the text body in the dataset


    def tryattribute( self, attr, value ) :
        """Check whether the parsed (attr, value) tuple matches an expected
        content and if so, stuff them into `self.dataset`

        This logic, uses `self.attributes` that should be defined in derived
        class.

        If this function returns `None` then attribute `attr` is not expected.
        """

        for a in self.attributes :  
            if attr in self.attributes[a] : # Yep, this content is expected
                self.dataset.setdefault( a, value )
                break
        else :                              # Nope, better luck next time
            a = None 

        return a


    def tryhblimiter( self, line ) :
        """Check whether `line` can be considered as a delimiter for head and
        body.

        This logic, uses `self.hbdelimiter` that should be defined in derived
        class.
        """

        line = line.strip( ' \t:,;\'"-][}{><@`()' )  # Sanitize

        if self.bodyname and (not line) : return self.bodyname

        for name in self.hbdelimiter :
            if line in self.hbdelimiter[name] :
                # Yep, the line is indeed a delimiter, and the delimiter type is
                # used to identify the body-text
                self.bodyname        = name
                self.dataset[ name ] = []
                break
        else :
            name = None
        return name


    def identify( self ) :
        """This function should be called after the text is fully parsed.
        Essentially this function identifies the text-bundle and validates
        the `dataset` and returns the verdict as True or False
        """
        attrs = self.dataset.keys()
        # Check whether the dataset is matching any of the valid combination of
        # `must attributes`
        rc    = any([ all([ mattr in attrs for mattr in mustattrs ])
                      for mustattrs in self.mustattrss ])
        # If so, then proceed whether the dataset is comprehensive
        rc    = (rc and self.validate()) or False
        return rc


    def appendbody( self, line ) :
        """self.dataset[ self.bodyname ] is a list of lines parsed from the
        text-bundle (after the delimiter) that can be consumed as `text`"""
        if self.bodyname :
            self.dataset[ self.bodyname ].append( line )


    def joinbody( self, withchars ) :
        """Join self.dataset[ self.bodyname ] into text paragraph"""
        if  self.bodyname :
            body = unicode(withchars.join( self.dataset[ self.bodyname ] ))
            self.dataset[ self.bodyname ] = body

    def validate( self ) :
        """The deriving class should implement this function"""
        return True


class Swiki( Structure ) :

    type = 'staticwiki'

    attributes = {
        'path'        : [ 'path', 'path-url', 'path url', 'url', 'pathurl' ]
    }

    mustattrss = [
        [ 'path' ],
    ]

    hbdelimiter= {
        'text' : [ '', 'text', 'page', 'description' ],
    }

    def validate( self ) :
        data = self.dataset
        rc   = True

        try :
            data['path'] = unicode( data['path'].lstrip( '/' ) )
            text         = data['text']
        except :
            rc = False
        return rc

    def commit( self, config, byuser, tz='UTC', attachments=[] ) :
        """If the identified structure is SWiki, commit the data to DB"""
        from zeta.comp.system  import SystemComponent

        compmgr = config['compmgr']
        syscomp = SystemComponent( compmgr )

        data = self.dataset
        path = data['path']
        text = data['text']
        syscomp.set_staticwiki( path, text, byuser=byuser )


class Attachment( Structure ) :

    type = 'attachment'

    attributes = {
        'id'          : [ 'attachment', 'attachmentid', 'attachment id',
                          'attachment-id' ],
        'projectname' : [ 'project', 'projectname', 'project-name', 'project_name',
                          'project name', ],
        'projectid'   : [ 'pid', 'projectid', 'project-id', 'project_id',
                          'project id' ],
        'summary'     : [ 'summary' ],
        'tags'        : [ 'tag', 'tags' ],
    }

    mustattrss = [
        [ 'id' ],
    ]

    hbdelimiter= {
        # There are not text-body in this text-bundle
    }

    def validate( self ) :
        data = self.dataset
        rc   = True
        try :
            if 'summary' in data :
                data['summary'] = unicode( data['summary'] )
            if 'tags' in data :
                data['tags'] = sanitizetags( data.get( 'tags', '' ))
            if 'id' in data :
                if data['id'].lower() == 'new' :
                    data['id'] = 0
                else :
                    data['id'] = int(data['id'])
            if 'projectname' in data :
                data['projectname'] = unicode( data['projectname'] )
            if 'projectid' in data :
                data['projectid'] = int( data['projectid'] )
        except :
            rc = False

        return rc

    def commit( self, config, byuser, tz='UTC', attachments=[] ) :
        """If the identified structure is Attachment, commit the data to DB"""
        from zeta.comp.attach  import AttachComponent
        from zeta.comp.project import ProjectComponent

        compmgr  = config['compmgr']
        attcomp  = AttachComponent( compmgr )
        projcomp = ProjectComponent( compmgr )

        data    = self.dataset
        aid     = data.get( 'id', None )
        summary = data.get( 'summary', None )
        tags    = data.get( 'tags', [] )
        p       = data.get( 'projectname', None )
        p       = p or data.get( 'projectid', None )
        p       = p and projcomp.get_project(p)
        if aid :
            att = attcomp.get_attach( aid )
            if summary !=None :
                attcomp.edit_summary( att, summary, byuser=byuser )
            if tags :
                attcomp.add_tags( att, tags, byuser=byuser )
        elif attachments :
            for fname, file in attachments :
                att = attcomp.create_attach( fname, FileC(file),
                                             uploader=byuser,
                                             summary=summary
                                           )
                p and projcomp.add_attach( p, att, byuser=byuser )
                tags and attcomp.add_tags( att, tags, byuser=byuser )
        return


class Wiki( Structure ) :

    type = 'wiki'

    attributes = {
        'wikiid'      : [ 'wikiid', 'wiki-id', 'wiki_id', 'wiki id' ],
        'pagename'    : [ 'page', 'pagename', 'page-name', 'page_name', 'page name' ],
        'wikiurl'     : [ 'wikiurl', 'wiki-url', 'wiki url' ],
        'projectname' : [ 'project', 'projectname', 'project-name', 'project_name',
                          'project name', ],
        'projectid'   : [ 'pid', 'projectid', 'project-id', 'project_id',
                          'project id' ],
        'type'        : [ 'type', 'wikitype', 'wiki-type', 'wiki_type', 'wiki type' ],
        'summary'     : [ 'summary' ],
        'tags'        : [ 'tag', 'tags' ],
        'favorite'    : [ 'favorite' ],
        'vote'        : [ 'vote' ]
    }

    mustattrss = [
        [ 'wikiid' ],
        [ 'wikiurl' ],
        [ 'projectname', 'pagename' ],
        [ 'projectid', 'pagename' ],
    ]

    hbdelimiter= {
        'text'    : [ 'description', 'text' ],
        'comment' : [ '', 'comment' ],
    }

    def validate( self ) :
        data = self.dataset
        rc   = True
        try :
            if 'wikiid' in data :
                data['wikiid'] = int( data['wikiid'] )
            if 'wikiurl' in data :
                data['wikiurl'] = unicode( data['wikiurl'] )
            if 'pagename' in data :
                data['pagename'] = unicode( data['pagename'] )
            if 'projectname' in data :
                data['projectname'] = unicode( data['projectname'] )
            if 'projectid' in data :
                data['projectid'] = int( data['projectid'] )
            if 'type' in data :
                data['type'] = unicode( data['type'] )
            if 'summary' in data :
                data['summary'] = unicode( data['summary'] )
            if 'tags' in data :
                data['tags'] = sanitizetags( data.get( 'tags', '' ))

            if 'favorite' in data :
                fav = sanitizebool( data['favorite'] )
                if fav != None :
                    data['favorite'] = fav
                else :
                    data.pop( 'favorite' )

            if 'vote' in data :
                vote = sanitizevote( data['vote'] )
                if vote :
                    data['vote'] = vote
                else :
                    data.pop( 'vote' )

        except :
            rc = False

        return rc

    def commit( self, config, byuser, tz='UTC', attachments=[] ) :
        """If the identified structure is Wiki, commit the data to DB"""
        from zeta.comp.wiki    import WikiComponent
        from zeta.comp.project import ProjectComponent
        from zeta.comp.attach  import AttachComponent

        compmgr  = config['compmgr']
        projcomp = ProjectComponent( compmgr )
        wikicomp = WikiComponent( compmgr )
        attcomp  = AttachComponent( compmgr )

        data    = self.dataset
        attrs = [ 'wikiid', 'pagename', 'wikiurl', 'projectname', 'projectid',
                  'type', 'summary', 'tags', 'favorite', 'vote',
                  'text', 'comment' ]

        kwargs      = dict([ (k, data.get(k, None)) for k in attrs ])
        pagename    = kwargs.pop( 'pagename', None )
        wikiurl     = kwargs.pop( 'wikiurl', None )

        p   = kwargs.pop( 'projectname', None )
        p   = p or kwargs.pop( 'projectid', None )
        p   = projcomp.get_project( p )

        w   = kwargs.pop( 'wikiid', None )
        w   = w or wikiurl
        w   = w and wikicomp.get_wiki( w )

        if pagename and p :
            wikiurl = h.url_for( h.r_projwiki, projectname=p.projectname, url=pagename )
            w = w or wikicomp.get_wiki( unicode(wikiurl) )

        if w :
            # Favorite
            fav  = kwargs.pop( 'favorite', None )
            fav == True and wikicomp.addfavorites( w, [byuser], byuser=byuser )
            fav == False and wikicomp.delfavorites( w, [byuser], byuser=byuser )

            # Vote
            vote = kwargs.pop( 'vote', '' )
            vote == 'up' and wikicomp.voteup( w, byuser )
            vote == 'down' and wikicomp.votedown( w, byuser )

            # Tags
            tags = kwargs.pop( 'tags', [] )
            tags and wikicomp.add_tags( w, tags=tags, byuser=byuser )

            # Comment
            comment = kwargs.pop( 'comment', None )
            comment and wikicomp.create_wikicomment(
                                    w, 
                                    (None, byuser, w.latest_version, comment),
                                    byuser=byuser
                        )

            # Type and summary
            wtype   = kwargs.pop( 'type', None )
            wtype   = wtype and wikicomp.get_wikitype( wtype )
            summary = kwargs.pop( 'summary', None )
            if wtype or summary :
                wikicomp.config_wiki( w, type=wtype, summary=summary,
                                      byuser=byuser )

            # Content
            text    = kwargs.pop( 'text', None )
            text and wikicomp.create_content( w, byuser, text )

        elif wikiurl :
            wtype   = kwargs.pop( 'type', None )
            wtype   = wtype and wikicomp.get_wikitype( wtype )
            summary = kwargs.pop( 'summary', u'' )

            w = wikicomp.create_wiki( unicode(wikiurl), type=wtype, summary=summary,
                                      creator=byuser )

            if w :
                # Favorite
                fav  = kwargs.pop( 'favorite', None )
                fav == True and wikicomp.addfavorites( w, [byuser], byuser=byuser )
                fav == False and wikicomp.delfavorites( w, [byuser], byuser=byuser )

                # Vote
                vote = kwargs.pop( 'vote', '' )
                vote == 'up' and wikicomp.voteup( w, byuser )
                vote == 'down' and wikicomp.votedown( w, byuser )

                # Tags
                tags = kwargs.pop( 'tags', [] )
                tags and wikicomp.add_tags( w, tags=tags, byuser=byuser )

                # Wiki content
                text = kwargs.pop( 'text', None )
                text and wikicomp.create_content( w, byuser, text )
               
        # Attachments
        if w :
            for fname, fcont in attachments :
                att = attcomp.create_attach( fname, FileC(fcont),
                                             uploader=byuser )
                wikicomp.add_attach( w, att, byuser=byuser )


class Ticket( Structure ) :

    type = 'ticket'

    attributes = {
        'ticket'      : [ 'ticket', 'tid', 'ticketid', 'ticket-id', 'ticket_id',
                          'ticket id',
                          'issue', 'issueid', 'issue-id', 'issue_id',
                          'issue id' ],
        'projectname' : [ 'project', 'projectname', 'project-name', 'project_name',
                          'project name', ],
        'projectid'   : [ 'pid', 'projectid', 'project-id', 'project_id',
                          'project id' ],
        'type'        : [ 'type', 'tickettype', 'ticket-type', 'ticket_type',
                          'ticket type' ],
        'severity'    : [ 'severity', 'ticketseverity', 'ticket-severity',
                          'ticket_severity', 'ticket severity' ],
        'summary'     : [ 'summary', 'sumary' ],
        'status'      : [ 'status', 'ticketstatus', 'ticket-status',
                          'ticket_status', 'ticket status' ],
        'duedate'     : [ 'duedate',  'due-date', 'due_date', 'due date' ],
        'promptuser'  : [ 'promptuser', 'prompt-user', 'prompt_user',
                          'prompt user' ],
        'components'  : [ 'comp', 'comps', 'component', 'components' ],
        'milestones'  : [ 'mstn', 'mstns', 'milestone', 'milestones' ],
        'versions'    : [ 'ver',  'vers',  'version', 'versions' ],
        'blocking'    : [ 'blocking' ],
        'blockedby'   : [ 'blockedby' ],
        'parent'      : [ 'parent' ],
        'tags'        : [ 'tag', 'tags' ],
        'favorite'    : [ 'favorite' ],
        'vote'        : [ 'vote' ]
    }

    mustattrss = [
        [ 'ticket' ],
        [ 'projectname', 'type', 'severity', 'summary' ],
        [ 'projectid', 'type', 'severity', 'summary' ],
    ]

    hbdelimiter= {
        'description' : [ 'description', 'text', ],
        'comment'     : [ '', 'comment' ],
    }

    def validate( self ) :
        data = self.dataset
        rc   = True

        try :
            if 'ticket' in data :
                data['ticket'] = int(data['ticket'])
            if 'projectname' in data :
                data['projectname'] = unicode( data['projectname'] )
            if 'type' in data :
                data['type'] = unicode( data['type'] )
            if 'severity' in data :
                data['severity'] = unicode( data['severity'] )
            if 'summary' in data :
                data['summary'] = unicode( data['summary'] )

            if 'status' in data :
                data['status'] = unicode( data['status'] )
            if 'duedate' in data :
                data['duedate'] = unicode( data['duedate'] )

            if 'promptuser' in data :
                data['promptuser'] = unicode( data['promptuser'] )
            if 'components' in data :
                vals = parse_csv( data.get( 'components', '' ))
                data['components'] = vals and vals[0] or None
            if 'milestones' in data :
                vals = parse_csv( data.get( 'milestones', '' ))
                data['milestones'] = vals and vals[0] or None
            if 'versions' in data :
                vals = parse_csv( data.get( 'versions', '' ))
                data['versions'] = vals and vals[0] or None
            if 'blocking' in data :
                data['blocking'] = sanitizevalues( data.get('blocking','' ))
            if 'blockedby' in data :
                data['blockedby'] = sanitizevalues( data.get('blockedby','' ))
            if 'parent' in data :
                data['parent'] = int(data['parent'])

            if 'tags' in data :
                data['tags'] = sanitizetags( data.get('tags', ''))

            if 'favorite' in data :
                fav = sanitizebool( data['favorite'] )
                if fav != None :
                    data['favorite'] = fav
                else :
                    data.pop( 'favorite' )

            if 'vote' in data :
                vote = sanitizevote( data['vote'] )
                if vote :
                    data['vote'] = vote
                else :
                    data.pop( 'vote' )

        except :
            rc = False

        return rc

    def commit( self, config, byuser, tz='UTC', attachments=[] ) :
        """If the identified structure is Ticket, commit the data to DB"""
        from zeta.comp.ticket  import TicketComponent
        from zeta.comp.project import ProjectComponent
        from zeta.comp.attach  import AttachComponent

        compmgr  = config['compmgr']
        projcomp = ProjectComponent( compmgr )
        tckcomp  = TicketComponent( compmgr )
        attcomp  = AttachComponent( compmgr )

        data    = self.dataset
        attrs = [ 'ticket', 'projectname', 'projectid', 'type', 'severity',
                  'summary', 'status', 'duedate', 'promptuser', 'components',
                  'milestones', 'versions', 'blocking', 'blockedby', 'parent',
                  'tags', 'favorite', 'vote', 'description', 'comment' ]
        kwargs= dict([ (k, data.get(k, None)) for k in attrs ])
        ticket= kwargs.pop( 'ticket', None )
        t     = ticket and tckcomp.get_ticket( ticket )
        if t :
            kwargs.pop( 'projectname', '' )
            kwargs.pop( 'projectid', '' )
            ts  = tckcomp.get_ticket_status( t.tsh_id )

            # Favorite
            fav  = kwargs.pop( 'favorite', None )
            fav == True and tckcomp.addfavorites( t, [byuser], byuser=byuser )
            fav == False and tckcomp.delfavorites( t, [byuser], byuser=byuser )

            # Vote
            vote = kwargs.pop( 'vote', '' )
            vote == 'up' and tckcomp.voteup( t, byuser )
            vote == 'down' and tckcomp.votedown( t, byuser )

            # Tags
            tags = kwargs.pop( 'tags', [] )
            tags and tckcomp.add_tags( t, tags=tags, byuser=byuser )

            # Comment
            comment = kwargs.pop( 'comment', None )
            comment and tckcomp.create_ticket_comment(
                                    t, 
                                    (None, comment, byuser),
                                    byuser=byuser
                        )

            # Summary and Description
            summary = kwargs.pop( 'summary', None )
            descr   = kwargs.pop( 'description', None )
            if (summary != None) or (descr != None) :
                tckdet = [ t.id, summary, descr, t.type, t.severity ]
                tckcomp.create_ticket( None, tckdet, t.promptuser,
                                       update=True, byuser=byuser )

            # Ticket status, duedate
            status = kwargs.pop( 'status', None )
            duedate= kwargs.pop( 'duedate', None )
            duedate= duedate and h.duedate2dt( duedate, tz ) or None
            if ( status == ts.status.tck_statusname and (duedate != None) )\
               or \
               ( (status == None) and (duedate != None) ) :
                # Just change the  duedate for current tsh
                tstatdet = [ ts.id, ts.status, duedate ]
                tckcomp.create_ticket_status( t, tstatdet, byuser,
                                              update=True, byuser=byuser )
            elif status : # New status
                tstatdet = [ None, status, duedate ]
                tckcomp.create_ticket_status( t, tstatdet, byuser, byuser=byuser )

            # Rest of the configuration 
            kwargs['byuser'] = byuser
            tckcomp.config_ticket( t, **kwargs )


        else :
            kwargs.pop( 'comment', '' )
            kwargs.pop( 'ticket', '' )
            kwargs.pop( 'status', '' )
            kwargs.pop( 'duedate', '' )

            pname = kwargs.pop( 'projectname', None )
            pid   = kwargs.pop( 'projectid', None )
            p     = pname or pid
            p     = p and projcomp.get_project( p )

            ttype    = kwargs.pop( 'type', None )
            severity = kwargs.pop( 'severity', None )
            summary  = kwargs.pop( 'summary', None )
            t        = None

            if p and ttype and severity and summary :
                descr  = kwargs.pop( 'description', None )
                puser  = kwargs.pop( 'prompuser', None )
                tckdet = ( None, summary, descr, ttype, severity )
                t      = tckcomp.create_ticket( p, tckdet, promptuser=puser,
                                                owner=byuser, byuser=byuser )

            if t :
                # Favorite
                fav  = kwargs.pop( 'favorite', None )
                fav == True and tckcomp.addfavorites( t, [byuser], byuser=byuser )
                fav == False and tckcomp.delfavorites( t, [byuser], byuser=byuser )

                # Vote
                vote = kwargs.pop( 'vote', '' )
                vote == 'up' and tckcomp.voteup( t, byuser )
                vote == 'down' and tckcomp.votedown( t, byuser )

                # Tags
                tags = kwargs.pop( 'tags', [] )
                tags and tckcomp.add_tags( t, tags=tags, byuser=byuser )

                # Rest of the Configuration for ticket
                kwargs['byuser'] = byuser
                tckcomp.config_ticket( t, **kwargs )
               
        # Attachments
        if t :
            for fname, fcont in attachments :
                att = attcomp.create_attach( fname, FileC(fcont),
                                             uploader=byuser )
                tckcomp.add_attach( t, att, byuser=byuser )


class Review( Structure ) :

    type = 'review'

    attributes = {
        'reviewid'    : [ 'reviewid', 'review-id', 'review_id', 'review id' ],
        'rcmtid'      : [ 'review-comment', 'review comment', 'review_comment' ],
        'projectname' : [ 'project', 'projectname', 'project-name', 'project_name',
                          'project name', ],
        'projectid'   : [ 'pid', 'projectid', 'project-id', 'project_id',
                          'project id' ],
        'position'    : [ 'position', 'lineno', 'line-no', 'line no' ],
        'nature'      : [ 'nature' ],
        'action'      : [ 'action' ],
        'approved'    : [ 'approved' ],
        'tags'        : [ 'tag', 'tags', ],
        'favorite'    : [ 'favorite' ],
    }

    mustattrss = [
        [ 'reviewid', 'position' ],
        [ 'rcmtid' ],
    ]

    hbdelimiter= {
        'comment' : [ '', 'comment' ],
    }

    def validate( self ) :
        data = self.dataset
        rc   = True
        try :
            if 'reviewid' in data :
                data['reviewid'] = int( data['reviewid'] )
            if 'projectname' in data :
                data['projectname'] = unicode( data['projectname'] )
            if 'projectid' in data :
                data['projectid'] = int( data['projectid'] )
            if 'rcmtid' in data :
                data['rcmtid'] = int( data['rcmtid'] )
            if 'position' in data :
                data['position'] = int( data['position'] )
            if 'nature' in data :
                data['nature'] = unicode( data['nature'] )
            if 'action' in data :
                data['action'] = unicode( data['action'] )
            if 'approved' in data :
                data['approved'] = sanitizebool( data['approved'] )
            if 'tags' in data :
                data['tags'] = sanitizetags( data.get( 'tags', '' ))

            if 'favorite' in data :
                fav = sanitizebool( data['favorite'] )
                if fav != None :
                    data['favorite'] = fav
                else :
                    data.pop( 'favorite' )

        except :
            rc = False

        return rc

    def commit( self, config, byuser, tz='UTC', attachments=[] ) :
        """If the identified structure is Review, commit the data to DB"""
        from zeta.comp.review  import ReviewComponent
        from zeta.comp.project import ProjectComponent
        from zeta.comp.attach  import AttachComponent

        compmgr  = config['compmgr']
        projcomp = ProjectComponent( compmgr )
        revcomp  = ReviewComponent( compmgr )
        attcomp  = AttachComponent( compmgr )

        data    = self.dataset
        attrs = [ 'reviewid', 'rcmtid', 'projectname', 'projectid', 'position', 
                  'nature', 'action', 'approved', 'tags', 'favorite', 'comment' ]

        kwargs= dict([ (k, data.get(k, None)) for k in attrs ])

        p   = kwargs.pop( 'projectname', None )
        p   = p or kwargs.pop( 'projectid', None )
        p   = p and projcomp.get_project( p )

        r    = kwargs.pop( 'reviewid', None )
        rcmt = kwargs.pop( 'rcmtid', None )
        r    = revcomp.get_review(r)

        nature  = kwargs.pop( 'nature', None )
        action  = kwargs.pop( 'action', None )
        approved= kwargs.pop( 'approved', None )
        position= kwargs.pop( 'position', None )
        comment = kwargs.pop( 'comment', None )

        if r and comment and position :
            revcomp.create_reviewcomment(
                                r, 
                                (None, position, comment, byuser, nature, None),
                                byuser=byuser
                    )
        elif rcmt :
            revcomp.process_reviewcomment(
                        rcmt, reviewnature=nature, reviewaction=action,
                        approve=approved, byuser=byuser
                    )
        if r :
            # Favorite
            fav  = kwargs.pop( 'favorite', None )
            fav == True and revcomp.addfavorites( r, [byuser], byuser=byuser )
            fav == False and revcomp.delfavorites( r, [byuser], byuser=byuser )

            # Tags
            tags = kwargs.pop( 'tags', [] )
            tags and revcomp.add_tags( r, tags=tags, byuser=byuser )



        # Attachments
        if r :
            for fname, fcont in attachments :
                att = attcomp.create_attach( fname, FileC(fcont),
                                             uploader=byuser )
                revcomp.add_attach( r, att, byuser=byuser )


class Context( object ) :
    """Context object that encapulates the text, parse it, bulding a dataset,
    identifying and sanitizing the data"""

    def __init__( self ) :

        # One object for each structured type.
        self.s          = Swiki()   
        self.a          = Attachment()   
        self.t          = Ticket()
        self.w          = Wiki()
        self.r          = Review()
        self.structures = [ self.s, self.t, self.w, self.a, self.r, ]
        self.strt       = None

    def tryattribute( self, attr, value ) :
        """Entry interface to each Structure Class object's `tryattribute`"""
        return any([ strt.tryattribute( attr, value ) for strt in self.structures ])

    def tryhblimiter( self, line ) :
        """Entry interface to each Structure Class object's `tryhblimiter`"""
        return any([ strt.tryhblimiter( line ) for strt in self.structures ])

    def identify( self ) :
        """Identify Structure object"""
        for strt in self.structures :
            if strt.identify() : break
        else :
            raise ZetaMailtextParse( 'Unable to identify the purpose of text !!' )
        self.strt = strt
        return strt

    def body( self, lines, splitchars ) :
        """Make body"""
        strt = self.strt
        [ strt.appendbody( line ) for line in lines ]
        strt.joinbody( splitchars )
        return strt

    def commit( self, config, byuser, tz='UTC', attachments=[] ) :
        """Commit context data"""
        self.strt and self.strt.commit( config, byuser, tz, attachments )


def parseattr( ctxt, line ) :
    """Parse the line for (key,value) pair and when it is found use the
    context object to stuff them into `dataset`."""

    parts = line.strip( ' \t' ).split( ':', 1 )

    if len(parts) == 2 :
        attr  = parts[0].strip( ' \t' ).lower()
        value = parts[1].strip( ' \t' )
        return ctxt.tryattribute( attr, value )
    return False
        

def parse( text ) :
    """Interface function, takes in the text and returns back parsed data,
    which is the Context object"""

    newline = '\n'
    lines   = sanitizepart( text, newline )

    ctxt = Context()

    try :
        # Parsing the head
        for i in range( len( lines )) :
            line = lines[i]
            if parseattr( ctxt, line ) : continue
            break
        else :
            i += 1
        # Parsing the delimiter
        for i in range( i, len(lines) ) :
            line = lines[i]
            if ctxt.tryhblimiter( line ) : continue
            break
        else :
            i += 1

        ctxt.identify()
        ctxt.body( lines[i:], newline )

    except ZetaMailtextParse, msg :
        rc = msg
    else :
        rc = ctxt

    return rc


#----------------------- Email text --------------------

def sanitizesubject( subject ) :
    """Remove leading white-space, reply, forward prefixes and mailing-list
    prefixes"""
    regex = [ r'^[ ]+',                 # Remove white space
              r'^(?i)re[ ]*:[ ]*',      # Remove reply prefix
              r'^(?i)fwd[ ]*:[ ]*',     # Remove forward prefixes
              r'^\[[^\]]*\]',           # Remove mailing-list prefixes
            ]
    for r in regex :
        subject = re.sub( r, '', subject )
        subject = subject.strip( ' \t' )
    return subject

def sanitizepart( textpart, newline ) :
    """Remove leading and trailing, white-spaces and emtpy lines and return
    textlines"""
    lines   = [ l.strip( ' \t' ) for l in textpart.replace( '\r\n', newline
                                                          ).replace( '\n', newline 
                                                          ).split( newline ) ]
    # Remove the leading empty lines
    while lines :
        if lines[0] : break
        lines.pop(0)
    # Remove the trailing empty lines
    while lines :
        if lines[-1] : break
        lines.pop(-1)
    return lines

def limittomarker( lines, marker ) :
    """Split lines across maker, start from top"""
    pivot = [ i for i in range(len(lines)) if lines[i].strip( ' \t' ) == marker ]
    pivot = pivot and pivot[0] or None
    head, tail = lines, []
    if pivot :
        head = lines[:pivot]
        tail = lines[pivot+1:]
    return head, tail

def stripreply( lines ) :
    """Strip all the lines that start with reply character, starting from
    bottom"""
    while lines :
        if lines[-1][0] == '>' or (not lines[-1].strip( ' \t' )) :
            lines.pop(-1)
        else :
            break
    return lines

def email2text( textparts ) :
    """Collate it into a text-bundle"""
    fulltext = ''
    for text in textparts :
        lines = stripreply( limittomarker( sanitizepart( text, '\n' ),
                                           EMAIL_ENDMARKER )[0]
                          )
        fulltext += '\n'.join(lines)
    return fulltext
