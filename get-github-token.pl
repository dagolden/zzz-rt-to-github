#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use Net::GitHub::V3;
use IO::Prompt::Tiny qw/prompt/;

my $user = prompt( "Github username:" );
my $pass = prompt( "Github password:" );
my $gh = Net::GitHub::V3->new( login => $user, pass => $pass );
my $oauth = $gh->oauth;
my $o = $oauth->create_authorization( {
    scopes => ['user', 'public_repo', 'repo', 'gist'],
    note   => 'Net::GitHub',
} );
say $o->{token};
