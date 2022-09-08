my $path = 'token/add-utr';

our @Param = paramSpread qw(Par_Token_Add $ O);
our ($P1, $P2) = paramAlias @Param;

sub tokenAddUtr {
  my $f = sub {
    our $Db = shift;
    our $Db_ = ucfirst lc ($Db);
    our $Bbr = $Db eq 'BB' ? 0 : 1;

    my $InsertToken = shr 2, view slurpp ("$path/insert-@{[lc $Db]}");
    my $InsertTokenProv = shr 2, view slurpp ("$path/insert-token-prov");

"if \@Has$Db_ then

$InsertToken

$InsertTokenProv

end if;"
  };

  $f->('BBR') . "\n\n" . $f->('BB');
}

1;
