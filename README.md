# rt-to-github

This repository contains `rt-to-github.pl`, a script for migrating CPAN RT
tickets to Github.

## Prerequisites

You'll need various CPAN modules installed.  See the `cpanfile` file
for a list of them.  If you use the `cpanm` CPAN client, you can install
them with this command from the repository directory:

```
$ cpanm --installdeps .
```

## Github token

You'll need a Github API token.  If you don't have one or know how to get
one, run the `get-github-token.pl` script.  If you put your token
into your `~/.gitconfig` file, `rt-to-github.pl` will use it as your
default Github credentials when prompting you.

They should live in a `github` section of the `.gitconfig` like this:

```
[github]
    user = dagolden
    token = e9c4fc1c59b35c2a4e5d6c0ce204dbd9bd74d7aa
```

## PAUSE credentials

If you have a `~/.pause` file, it will be used as the defaults when
prompting for PAUSE credentials.  A `.pause` file must list credentials
like this:

```
user DAGOLDEN
password trustN01
```

## How to use rt-to-github.pl

Change to the checked out repository directory.  If the basename of the
directory matches your repository name (which is common for git clones),
it will be the default repository name.

If your repository has a `dist.ini` file and you have `name = ...` as
the first line, that will be used for the default RT distribution
name. Otherwise, if you have a `MYMETA.json` or `META.json` (or the YAML
equivalents), those will be used to find the distribution name default.

Run `rt-to-github.pl`.  You will be prompted for Github and PAUSE
information.  If you set things up following the instructions above,
all the prompts should be correct and you'll see your tickets migrated.

**Note**, if you are migrating to an **organization** repository, use
the organization name for the "repo owner" field instead of your github
user name.

For a "dry-run" use the `-n` flag.  That will dump the full text of each
ticket to show how the migrated ticket would look.

To migrate only a single ticket, use `-t <ticket-number>`.

Here's an example of how I migrated all tickets for IO::CaptureOutput:

```
$ cd ~/git/IO-CaptureOutput
$ rt-to-github.pl
github user:  [dagolden]
github token:  [e9c4fc1c59b35c2a4e5d6c0ce204dbd9bd74d7aa]
repo owner:  [dagolden]
repo name:  [IO-CaptureOutput]
PAUSE ID:  [DAGOLDEN]
RT dist name:  [IO-CaptureOutput]
ticket #55165 (Forcing quoting in w...) copied to github as #6 (https://github.com/dagolden/IO-CaptureOutput/issues/6)
ticket #41444 (Cleaning up temporar...) copied to github as #7 (https://github.com/dagolden/IO-CaptureOutput/issues/7)
ticket #55164 (Bad joining of STDER...) copied to github as #8 (https://github.com/dagolden/IO-CaptureOutput/issues/8)
ticket #80017 (make exit_code direc...) copied to github as #9 (https://github.com/dagolden/IO-CaptureOutput/issues/9)
ticket #21829 (Temp File Removal Er...) copied to github as #10 (https://github.com/dagolden/IO-CaptureOutput/issues/10)
ticket #45023 (skip on windows "Can...) copied to github as #11 (https://github.com/dagolden/IO-CaptureOutput/issues/11)
```

Be patient, the RT REST API can be a bit slow as all the bits of
information are pulled down to populate the new Github issue.

## Contributing

I'm open to contributions that make this script better.  Feel free to
open an issue or send a pull request.

## See also

A precusor to this script was published in the article [How to move CPAN RT
tickets to
Github](http://www.dagolden.com/index.php/1938/how-to-move-cpan-rt-tickets-to-github/).

The version in this respository was introduced in a subsequent article,
[Moving CPAN RT tickets to Github, now
improved](http://www.dagolden.com/index.php/2397/moving-cpan-rt-tickets-to-github-now-improved/).

The original script and subsequent improvements were based on or inspired
by the work of others:

* [Bandying Tickets from RT to Github
  Issues](http://www.pythian.com/blog/bandying-tickets-from-rt-to-github-issues/)
  was broken so I adapted it for the new Github API.
* [rt-to-github.pl](https://gist.github.com/markstos/5096483) an adaptation
  of my original by Mark Stosberg added some features like importing
  all comments (though differently than how I wound up doing it).

While I never used it, Lee Johnson also created a RT to Github migration
tool based on Mark's adaptation of mine.  He's since removed it in favor of
this one, but you can see his final version
[here](https://github.com/leejo/rt-to-github/blob/fa311bce986eeef2c844659ee9d36e50364e361c/rt-to-github.pl).

## License

This software is Copyright (c) 2015 by David Golden.

This is free software, licensed under The Apache License, Version 2.0,
January 2004.
