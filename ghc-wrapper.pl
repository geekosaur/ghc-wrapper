#! /usr/bin/perl
#
# wrapper for ghc and friends
#
# use basename as program to look for
# if /opt/ghc exists, we use the latest version listed there
# $USEGHC in environment overrides this; if -, use one on $PATH that isn't us
# (basically we ignore it if it starts with #!...perl...)
# likewise for alex, happy, cabal and corresponding USEXXX
#

#
# @@@@@@@@
#
# - fix version comparison
#     see .debs in ~/Downloads for head, prerelease
# - install mode, if run as something not in the list we take --install[=PATH],
#     --remove[=PATH], --version
# - for --install, use first of hardlink/symlink/copy that works
# - --clean[=PATH] check & maybe remove dangling copies
#     this wants something smarter than the fast self-check!
# - windows support? (paths, extensions)
# - POD documentation
# - factor out self-check for install mode
# - USEXXX=release USEXXX=-|system USEXXX=head|devel (USEXXX=prerelease?)
# - USEXXX=anyVERSION (also look for version on $PATH instead of forcing /opt)
#     ...and maybe that should be the default? esp. with below
# - /opt not hardcoded; allow a list of repo locations
# - maybe someday: %pkgs and above from .config
# - better error checking, e.g. no /opt or /opt/$whats{$what}
# - buff $ENV{GHC_WRAPPER_TEST} into a real control mechanism
#     e.g. the clean check could use --version and GHC_WRAPPER_MODE=installer
#

use 5.012;

use strict;
use warnings;

# known packages and programs
my %pkgs = (ghc => [qw(hp2ps runghc ghc-pkg hpc hsc2hs
		       ghc haddock runhaskell ghci)],
	    alex => [qw(alex)],
	    happy => [qw(happy)],
	    cabal => [qw(cabal)],
	   );
# inverted index for same
my %whats;
{
  for my $pkg (keys %pkgs) {
    for my $bin (@{$pkgs{$pkg}}) {
      die "ghc-wrapper: duplicate $bin (was $whats{$bin}, now $pkg)"
	if exists $whats{bin};
      $whats{$bin} = $pkg;
    }
  }
}

# what am I wrapping?
my $what = $0;
$what =~ s,.*/,,;
unless (exists $whats{$what}) {
  die "ghc-wrapper: unknown program \"$what\"\n";
}

my $where;

# find a suitable installation of the package
my $use = 'USE' . uc $whats{$what};
# ...specific one via envar
if (exists $ENV{$use} && $ENV{$use} ne '' && $ENV{$use} ne '-') {
  if ($ENV{use} =~ /^\./ || $ENV{$use} =~ m,/,) {
    die "ghc-wrapper: $use ($ENV{$use}) is not safe\n";
  }
  elsif (! -x "/opt/$whats{$what}/$ENV{$use}/bin/$whats{$what}") {
    die "ghc-wrapper: $whats{$what} $ENV{$use} doesn't seem to be installed\n";
  }
  else {
    $where = "/opt/$whats{$what}/$ENV{$use}/bin";
  }
}
# ...latest hvr version, if one exists
if (!defined $where && !exists $ENV{$use} && -d "/opt/$whats{$what}") {
  my @ghcs;
  opendir my $d, "/opt/$whats{$what}"
    or die "ghc-wrapper($what): /opt/$whats{$what}: $!";
  while (readdir $d) {
    next if /^\./;
    next unless -x "/opt/$whats{$what}/$_/bin/$whats{$what}";
    # @@@@@@@@ dumb lexical comparison
    # @@ need to wait to see what prereleases look like
    # @@ also need to see what HEAD build looks like
    push @ghcs, $_;
  }
  closedir $d;
  if (@ghcs) {
    @ghcs = sort {$b cmp $a} @ghcs;
    $where = "/opt/$whats{$what}/$ghcs[0]/bin";
  }
}
# ...try $PATH for system or otherwise installed
if (!defined $where) {
  for my $d (split /:/, $ENV{PATH}) {
    if (-x "$d/$whats{$what}") {
      # making sure it's not us
      if (!open my $f, '<', "$d/$whats{$what}") {
	die "ghc-wrapper: $d/$whats{$what} unreadable: $!\n";
	# in theory could just assume it's safe, since a script would need
	# to be readable to be run, so it must be a binary
	#$where = $d;
      } else {
	# only first 64 bytes, in case it is a binary
	binmode $f;
	defined read $f, $_, 64
	  or die "ghc-wrapper: read $d/$whats{$what}: $!";
	close $f;
	if ($_ eq '') {
	  # in theory, could just let it go; user will find out
	  # soon enough. in practice, it would be confusing
	  die "ghc-wrapper: $d/$whats{$what} empty?\n";
	}
	elsif (/^#![^\r\n]*perl/) {
	  # assume it's us or some other potentially unsafe wrapper
	  # (note that the official "binaries" are shell wrappers)
	  warn "ghc-wrapper: avoiding myself ($d/$whats{$what})\n"
	    if exists $ENV{GHC_WRAPPER_TEST};
	}
	else {
	  $where = $d;
	  last;
	}
      }
    }
  }
}
if (!defined $where) {
  die "ghc-wrapper: can't find a $whats{$what} installation\n";
}
if (!-x "$where/$what") {
  die "ghc-wrapper: $whats{$what} installation doesn't have \"$what\"\n";
}

die "ghc-wrapper: would run $where/$what @ARGV\n"
  if exists $ENV{GHC_WRAPPER_TEST};
exec "$where/$what", @ARGV;
