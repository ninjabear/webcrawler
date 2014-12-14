#!perl

use strict;
use LWP::Simple;

$| = 1;

my $instanceLimit = 1000;
my $instanceCount = 0;

my @ParseableContentTypes;    # could pass these into crawl as references
my @DownloadContentTypes;

# ^^ footnote
# these can be partial or some regex

@DownloadContentTypes = ( "image", "text" );    #examples
@ParseableContentTypes = ("text");

my %seen;                                       # the urls we've seen so far

crawl( $ARGV[0], $ARGV[1] );

print "There's nowhere else to go!";

sub crawl() {
    if ( ++$instanceCount > $instanceLimit ) {
        print "instance limit reached! Collapsing instance. \n";
        return;
    }

    my $url          = @_[0];
    my $domainStrict = @_[1];
    print stderr "crawl ($url, $domainStrict);\n";
    my $content;    # content received from the server

    my $contentType, my $contentSize;    # information on the content
    my $modifiedTime,
    my $expiresTime;    # could probably ignore these, but hey, freebees.
    my $serverType;

    ( $contentType, $contentSize, $modifiedTime, $expiresTime, $serverType ) =
      head($url);

    if (defined $contentType)  # enough info to continue (implies server is up too)
    {
        #consider ignore/warn if contentSize > toomuchtodownload

        #if its a parsable type, download it and parse it
        #if its a downloadable type download and put it to disc
        #if its both, download, parse and save to disc
        #if its none; ignore, collapsing recursion

        if (   regexArrayHasMatch( \@ParseableContentTypes, $contentType )
            || regexArrayHasMatch( \@DownloadContentTypes, $contentType ) )
        {
            # we need to download, one matches
            print "downloading $url\r";
            $content = get($url);
            if ( defined $content ) {
                print "download of $url completed\n";

                # sucessfully have the data
                # stick it on the disc for now
                my $filename;

                $filename = randstr(8);

                $filename .= "{" . $contentType . "}" . $url;
                $filename =~ s/\W+/_/g;
                open contentfile, "+>" . $filename
                  or die "couldn't create content file - $!";
                binmode(contentfile);
                print contentfile $content;
                $content = "";    # clear content before we may
                                  # go recurse
                close contentfile;

                # parse if necessary
                my $fetchArrayRef;
                if ( regexArrayHasMatch( \@ParseableContentTypes, $contentType )
                  )
                {
                    print "parsing downloaded content - $url\n";
                    $fetchArrayRef = parse($filename); # parse the file for urls
                }

                # lets loop through the urls
                # and crawl those we haven't already seen and match the criteria

                foreach my $crawledUrl ( @{$fetchArrayRef} ) {
                    if ( !exists $seen{$crawledUrl} ) {
                        print "\tparse returned $crawledUrl\n";
                        $seen{$crawledUrl} = 1;
                        if ($domainStrict) {
                            if ( matchesDomain( $crawledUrl, $url ) ) {
                                crawl ( $crawledUrl, $domainStrict );
                            }
                            else {
                                print "\tdoesn't match domain\n";
                            }
                        }
                        else {
                            crawl ( $crawledUrl, $domainStrict );
                        }
                    }
                }

                # if its not in the downloadable, delete it

                # could probably remember this from before
                # although more efficient - i think this is clearer
                unless ( regexArrayHasMatch( \@DownloadContentTypes, $contentType ) )
                {
                    print "deleting temporary file $filename\n";
                    unlink($filename) or die "couldn't delete temporary file - $!";
                }

            }
            else {
                #failure getting data, moan and continue next url
                print stderr "failure getting crawl data for crawl($url, $domainStrict);\n";
            }
        }
        else {
            # we don't need the content, move on
        }

    }
    else {
        #head() failed
        #moan (most likely the server is down)
        #move on
        print stderr "couldn't head() for crawl($url, $domainStrict);\n";
    }
    return;
}

sub matchesDomain() {
    my $firstUrl  = @_[0];
    my $secondUrl = @_[1];

    # strip to domain and check for equality
    if   ( returnDomain($firstUrl) eq returnDomain($secondUrl) ) { return 1; }
    else                                                         { return 0; }
}

sub returnDomain() {

    #strips urls for domains
    #returns the domain as a string or "" on failure
    $_[0] =~ m#(http://)?(www.)?([^/]+)#i;
    if   ( defined $3 ) { return $3; }
    else                { return ""; }
}

sub regexArrayHasMatch() {

    #does what it says on the tin

		#two parameters
		#1 - an array reference containing all regex match checks to perform on test data
		#2 - a string of text

    #returns 1 if the regex array has an element which matches test

    my $regexArrayRef = @_[0];    # be sanitized (the array not the ref)
    my $testString    = @_[1];

    foreach my $regex ( @{$regexArrayRef} ) {
        if ( $testString =~ m/$regex/i ) { return 1; }
    }

    return 0;
}

sub randstr {

    # generate random string
    # of @_[0] length
    my @chars;
    my $beef;
    @chars = ( "a" .. "z", "A" .. "Z" );

    for ( 1 .. @_[0] ) {
        $beef .= $chars[ rand(@chars) ];
    }

    return $beef;

}

sub parse() {

		# returns an array (reference) containing urls
		# you could go crazy here and do it for all kinds but i'm only going to be simple
		# and add an example or two of how this should be done

    my @returnUrls;
    my $parseFilename = @_[0];

    push @returnUrls, @{ parseFullUrls($parseFilename) };

		# push @returnUrls, @{ thisfunctiondoesn'texistbutitmightparsesomekindoftagornotfullurls() };

    return \@returnUrls;
}

sub parseFullUrls() {
    my $filename = @_[0];
    my @returnUrls;
    open parsefile, "<" . $filename or die $!;
    while (<parsefile>) {
        if (m#http://(www\.)?[^\s"'>]+#i) {
            push @returnUrls, $&;
        }
    }
    close parsefile;

    return \@returnUrls;
}
