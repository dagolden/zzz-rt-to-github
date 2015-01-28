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
use RT::Client::REST::Ticket;
use RT::Client::REST;
use Syntax::Keyword::Junction qw/any/;
use Try::Tiny;
use Getopt::Long;

my $dry_run;
GetOptions( "dry-run|n" => \$dry_run );

my $pause_rc = path( $ENV{HOME}, ".pause" );
my %pause;

sub _git_config {
    my $key = shift;
    chomp( my $value = `git config --get $key` );
    croak "Unknown $key" unless $value;
    return $value;
}

sub _pause_rc {
    my $key = shift;
    if ( $pause_rc->exists && !%pause ) {
        %pause = split " ", $pause_rc->slurp;
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

my $rt = RT::Client::REST->new( server => 'https://rt.cpan.org/' );
$rt->login(
    username => $rt_user,
    password => $rt_password
);

# see which tickets we already have on the github side
my @gh_issues =
  $gh_issue->repos_issues( $github_repo_owner, $github_repo, { state => 'all' } );

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
    my $body =
      "Migrated from [rt.cpan.org#$id](https://rt.cpan.org/Ticket/Display.html?id=$id)";

    # requestor email addresses
    my $requestors = join( "", map { "* $_\n" } $ticket->requestors );
    $body .= "\nRequested by:\n$requestors";

    # attachment URLs (if any)
    my @attach_links;
    my $attach = $ticket->attachments->get_iterator;
    while ( my $i = $attach->() ) {
        my $name = $i->file_name or next;
        my $xact = $i->transaction_id;
        my $id   = $i->id;
        push @attach_links, "[$name](https://rt.cpan.org/Ticket/Attachment/$xact/$id/$name)";
    }
    if (@attach_links) {
        my $attach_list = join( "", map { "* $_\n" } @attach_links );
        $body .= "\nAttachments:\n$attach_list\n";
    }

    # initial ticket text
    my $create = $ticket->transactions( type => 'Create' )->get_iterator->();
    $body .= sprintf( "\n```\n%s\n```\n", $create->content );

    # subsequent ticket discussion
    my $comments = $ticket->transactions( type => 'Correspond' )->get_iterator;
    while ( my $c = $comments->() ) {
        $body .= sprintf( "\n```\n%s\n```\n", $c->content );
    }

    utf8::encode($body);

    # XXX always dry run for now
    if ( 1 || $dry_run ) {
        say "ticket #$id ($subject) would be copied to github as:";
        $body =~ s/^/    /gm;
        say "$subject\n\n$body\n";
    }
    else {
        my $isu;
        try {
            $isu = $gh_issue->create_issue(
                {
                    "title" => "$subject [rt.cpan.org #$id]",
                    "body"  => $body,
                }
            );
        }
        catch {
            say "ticket #$id ($subject) had an error posting to Github: $_";
            next TICKET;
        };

        my $gh_id  = $isu->{number};
        my $gh_url = $isu->{html_url};
        say "ticket #$id ($subject) copied to github as #$gh_id ($gh_url)";

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
