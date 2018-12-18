#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use Carp;
use CPAN::Meta;
use Encode qw/decode/;
use IO::Prompt::Tiny qw/prompt/;
use Net::GitHub;
use Path::Tiny;
use RT::Client::REST;
use RT::Client::REST::Ticket;
use RT::Client::REST::User;
use Syntax::Keyword::Junction qw/any/;
use Try::Tiny;
use Getopt::Long;

binmode( STDOUT, ":utf8" );

my $dry_run;
my $ticket;
GetOptions(
    "dry-run|n"  => \$dry_run,
    "ticket|t=i" => \$ticket
);

my $RT_SERVER = "rt.cpan.org";
my $pause_rc = path( $ENV{HOME}, ".pause" );
my %pause;
my %user_cache;

sub _git_config {
    my $key = shift;
    chomp( my $value = `git config --get $key` );
    croak "Unknown $key" unless $value;
    return $value;
}

sub _pause_rc {
    my $key = shift;
    if ( $pause_rc->exists && !%pause ) {
        my @pause = split qr{$/}, $pause_rc->slurp;
        for my $line (@pause) {
            my @credentials = split ' ', $line;
            my $key_name = shift @credentials;
            $pause{$key_name}
                = $key_name eq 'password'
                ? join ' ', @credentials
                : shift @credentials;
        }
    }
    return $pause{$key} // '';
}

sub _dist_name {
    my ($meta) = grep { -r } qw/MYMETA.json MYMETA.yml META.json META.yml/;
    if ($meta) {
        my $cm = CPAN::Meta->new($meta);
        return $cm->name;
    }
    elsif ( -r 'dist.ini' ) {
        # dzil only for now
        my $dist = path("dist.ini");
        my ($first) = $dist->lines( { count => 1 } );
        my ($name) = $first =~ m/name\s*=\s*(\S+)/;
        return $name if defined $name;
    }

    return '';
}

sub _find_from {
    my ( $xact ) = @_;

    # hack for 'http' or 'https' user which does not exist
    if ( $xact->creator =~ m{^https?://} ) {
        return sprintf("From %s on %s:", $xact->creator, $xact->created);
    }

    my $user = $user_cache{ $xact->creator } ||= RT::Client::REST::User->new(
        id => $xact->creator,
        rt => $xact->rt,
    );
    $user->retrieve;

    return sprintf("From %s on %s:", lc( $user->email_address // "unknown" ), $xact->created);
}

my $github_user       = prompt( "github user: ",  _git_config("github.user") );
my $github_token      = prompt( "github token: ", _git_config("github.token") );
my $github_repo_owner = prompt( "repo owner: ",   $github_user );
my $github_repo       = prompt( "repo name: ",    path(".")->absolute->basename );

my $rt_user = prompt( "PAUSE ID: ", _pause_rc("user") );
my $rt_password =
  _pause_rc("password") ? _pause_rc("password") : prompt("PAUSE password: ");
my $rt_dist = prompt( "RT dist name: ", _dist_name() );

my $gh = Net::GitHub->new( access_token => $github_token );
$gh->set_default_user_repo( $github_repo_owner, $github_repo );
my $gh_issue = $gh->issue;

my $rt = RT::Client::REST->new( server => "https://$RT_SERVER/" );
$rt->login(
    username => $rt_user,
    password => $rt_password
);

# see which tickets we already have on the github side
my @gh_issues =
  $gh_issue->repos_issues( $github_repo_owner, $github_repo, { state => 'all' } );

# repos_issues may not return all issues, so need to check
# if there are more and keep going until we have them all
while ( $gh_issue->has_next_page ) {
  my @next_page = $gh_issue->next_page;
  push( @gh_issues,@next_page );
}

my %rt_gh_map;
for my $i (@gh_issues) {
    if ( $i->{title} =~ /\[rt\.cpan\.org #(\d+)\]/ ) {
        $rt_gh_map{$1} = $i;
    }
}

my @rt_tickets = $rt->search(
    type  => 'ticket',
    query => qq{
        Queue = '$rt_dist'
        and
        ( Status = 'new' or Status = 'open' or Status = 'stalled')
    },
);

TICKET: for my $id (@rt_tickets) {

    # maybe only a single ticket
    next TICKET if $ticket && $id != $ticket;

    print "Importing RT #$id\n";

    # skip if already migrated
    if ( my $issue = $rt_gh_map{$id} ) {
        say "ticket #$id already on github as $issue->{number} ($issue->{html_url})";
        next;
    }

    # get the information from RT
    my $ticket = RT::Client::REST::Ticket->new(
        rt => $rt,
        id => $id,
    );
    $ticket->retrieve;

    # subject and initial body text
    my $subject = $ticket->subject;
    my $trunc_subject =
      length($subject) <= 20 ? $subject : ( substr( $subject, 0, 20 ) . "..." );
    my $status = $ticket->status;
    my $body =
      "Migrated from [$RT_SERVER#$id](https://$RT_SERVER/Ticket/Display.html?id=$id) (status was '$status')\n";


    # requestor email addresses
    my $requestors = join( "", map { "* $_\n" } $ticket->requestors );
    $body .= "\nRequestors:\n$requestors";

    # attachment URLs (if any)
    my @attach_links;
    my $attach = $ticket->attachments->get_iterator;
    while ( my $i = $attach->() ) {
        my $xact = $i->transaction_id;
        my $id   = $i->id;
        my $name = $i->file_name or next;
        push @attach_links, "[$name](https://$RT_SERVER/Ticket/Attachment/$xact/$id/$name)";
    }
    if (@attach_links) {
        my $attach_list = join( "", map { "* $_\n" } @attach_links );
        $body .= "\nAttachments:\n$attach_list\n";
    }

    # initial ticket text
    my $create = $ticket->transactions( type => 'Create' )->get_iterator->();
    my $op = _find_from($create);
    $body .= sprintf( "\n$op\n```\n%s\n```\n", $create->content );

    # subsequent ticket discussion
    my $comments = $ticket->transactions( type => 'Correspond' )->get_iterator;
    while ( my $c = $comments->() ) {
        my $from = _find_from($c);
        $body .= sprintf( "\n$from\n```\n%s\n```\n", $c->content );
    }


    if ( $dry_run ) {
        say "ticket #$id ($trunc_subject) would be copied to github as:";
        $body =~ s/^/    /gm;
        say "    Subject: $subject\n\n$body\n";
    }
    else {
        utf8::encode($subject);
        utf8::encode($body);
        my $isu;
        try {
            $isu = $gh_issue->create_issue(
                {
                    "title" => "$subject [$RT_SERVER #$id]",
                    "body"  => $body,
                }
            );
        }
        catch {
            say "ticket #$id ($trunc_subject) had an error posting to Github: $_";
            next TICKET;
        };

        my $gh_id  = $isu->{number};
        my $gh_url = $isu->{html_url};
        say "ticket #$id ($trunc_subject) copied to github as #$gh_id ($gh_url)";

        try {
            $rt->correspond(
                ticket_id => $id,
                message   => "Ticket migrated to github as $gh_url"
            );
            $ticket->status("resolved");
            $ticket->store;
        }
        catch {
            say "Error closing ticket #$id";
            next TICKET;
        };
    }
}
