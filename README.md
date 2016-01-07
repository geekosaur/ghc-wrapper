# ghc-wrapper: run selected ghc tool versions
This is a work in progress and very much incomplete, although good enough
for simple uses (like, getting me off of ancient Debian packages). It knows
about the packages provided by
[hvr's PPA](https://launchpad.net/~hvr/+archive/ubuntu/ghc).

Currently this must be installed manually by symlinking `ghc-wrapper.pl`
to the names of various tools as listed in `%pkgs`.

You use it by setting `$USEGHC` (or `$USEHAPPY`, `$USEALEX`, `$USECABAL`) to
an appropriate version found under `/opt/{ghc,happy,alex,cabal}`. By default
it will use the latest release version it finds there. You can also set it to
`"-"` to force use of a version found on `$PATH`; it will detect and ignore
itself to avoid infinite loops.
