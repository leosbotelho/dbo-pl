use strict;

use Pre::Candy qw(slurp);
use Text::Template qw(fill_in_string);

die "invalid env\n" unless defined $ENV{BB_DirpathAbs};

my $path = "$ENV{BB_DirpathAbs}/view";

sub slurpv { slurp "$path/$_[0]" }

my $tpl = slurp $ARGV[0];

print fill_in_string ($tpl);
