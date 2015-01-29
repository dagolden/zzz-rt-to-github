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

## Contributing

I'm open to contributions that make this script better.  Feel free to
open an issue or send a pull request.

## See also

A precusor to this script was published in the article [How to move CPAN RT
tickets to
Github](http://www.dagolden.com/index.php/1938/how-to-move-cpan-rt-tickets-to-github/).

The version in this respository was introduced in a subsequent article,
[Moving CPAN RT tickets to Github, now
improved](http://www.dagolden.com/index.php/2397/moving-rt-tick…b-now-improved/).

The original script and subsequent improvements were based on or inspired
by the work of others:

* [Bandying Tickets from RT to Github
  Issues](http://www.pythian.com/blog/bandying-tickets-from-rt-to-github-issues/)
  was broken so I adapted it for the new Github API.
* [rt-to-github.pl](https://gist.github.com/markstos/5096483) an adaptation
  of my original by Mark Stosberg added some features like importing
  all comments (though differently than how I wound up doing it).

While I haven't used it, leejo also created a [RT to Github migration
tool](https://github.com/leejo/rt-to-github) based on Mark's adaptation of
mine.

## License

This software is Copyright (c) 2015 by David Golden.

This is free software, licensed under The Apache License, Version 2.0,
January 2004.
