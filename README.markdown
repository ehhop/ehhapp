EHHapp
======

**A mobile-optimized wiki built on [git-wiki][].**

The EHHapp is a user editable version of the original [EHHOP mobile website][] (sometimes
called the Referrals App), which contained pocket reference information that may be
useful to clinicians at the [EHHOP clinic][].

By making it user editable, the aim is to allow information to be more up to date and allow
EHHOP clinicians to self-manage the reference information that they need.

The editability functionality was forked from [git-wiki][], a wiki that relies on git to 
keep pages' history and [Sinatra][] to serve them.

Install
-------

The EHHapp is a Ruby/Rack web application.  Ruby is preinstalled on most Macs and packaged for
most Linuxes.  You should also install [Rubygems][gems].  The following gems are 
required:

- [Sinatra][]
- [mojombo-grit][]
- [Liquid][]
- [RDiscount][]

It is usually simplest to install the `bundler` gem and then within your checkout's directory,
run `bundle install` to install all required gems.

Then, note the sample configuration file: config.dist.yaml, copy it to a new file: config.yaml. This file can be customized as needed (e.g. toggle authorization on and off).

Finally, run the EHHapp with `mkdir ehhapp-data && (cd ehhapp-data && git init) && rackup -p4567`

Create a local config.yaml file. You can use this file to overload default options in config.dist.yaml.

Then, run the EHHapp with `mkdir ehhapp-data && (cd ehhapp-data && git init) && rackup -p4567`

and point your browser at <http://0.0.0.0:4567/>.

Data will be stored in a git repository in the ehhapp-data folder.

For deployment, the EHHapp is comparable to most Rack apps and could be served with, e.g., 
Nginx/Passenger or Nginx/Unicorn.

[EHHOP mobile website]: http://ehhop0.appspot.com
[EHHOP clinic]: http://icahn.mssm.edu/education/medical/clinical/ehhop
[git-wiki]: https://github.com/sr/git-wiki
[Sinatra]: http://www.sinatrarb.com
[GitHub]: https://github.com/sr/git-wiki
[al3x]: https://github.com/al3x/gitwiki
[gems]: http://www.rubygems.org/
[mojombo-grit]: https://github.com/mojombo/grit
[Liquid]: http://www.liquidmarkup.org
[RDiscount]: https://github.com/rtomayko/rdiscount
[tip]: http://wiki.infogami.com/using_lynx_&_vim_with_infogami
[WiGit]: http://el-tramo.be/software/wigit
[ikiwiki]: http://ikiwiki.info

License
-------

The MIT License (MIT)

Copyright (c) 2013 East Harlem Health Outreach Partnership

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
