use strict;

use Text::Template qw(fill_in_string);
use Arr qw(OrdHash hashKey toArr);
use Pre qw(Rs $I);
use Pre::Candy qw(slurp);
use Fmt;
use Getopt::Long;
use POSIX qw(ceil);

use constant BB => 1;
use constant BBR => 2;

use constant IntMin => -2**31;

sub view { fill_in_string @_ }

die "invalid env\n" unless defined $ENV{BB_DirpathAbs};

my $path = "$ENV{BB_DirpathAbs}/proc";

our $RamDisk = q{Engine=MyIsam Data Directory='/var/ramdisk'};

sub slurpp { slurp "$path/$_[0]" }

sub requirep { require "$path/$_[0]" }

our $procOpt;
our $paramOpt = 0;

GetOptions (
  'proc' => \$procOpt,
  'param' => \$paramOpt
);

$procOpt = 1 unless $paramOpt;

my $CreateOrReplaceRe = qr/create\s+(?:or\s+replace\s+)?/;

sub eraseParam {
  $_[0] =~ s/\s?${CreateOrReplaceRe}table.*(Engine=Memory|\Q$RamDisk\E)\s*;\s?//sgri;
}

sub eraseProc { $_[0] =~ s/\s?${CreateOrReplaceRe}procedure.*\Z//msgri; }

our $ProcName;

sub getProcName_ {
  if ($_[0] =~ /${CreateOrReplaceRe}procedure\s+(.*?)\s*\(/ig) {
    return $1;
  }
  undef;
}

our $paramSelf = '$';
our $paramSep = '_';

sub paramSpread {
  my $Param = shift;
  map { $Param . ($_ eq $paramSelf ? '' : $paramSep . $_) } @_;
}

sub paramAlias { map { "$_[$_] P" . ($_ + 1) } (0..@_) }

sub paramSz {
  return '' unless $paramOpt;
  die unless $_[0] =~ /([0-9]+)(\s*[kmg])?/i;
  my ($sz, $u) = ($1, $2);
  $u = 1024 ** (
    $u eq 'k' ? 1 :
    $u eq 'm' ? 2 :
    $u eq 'g' ? 3 :
                0
  );
  $sz = 2 ** ceil(log ($sz * $u) / log (2));
  "set max_heap_table_size=$sz;"
}

sub genSqlCode {
  my %a = ();
  my $i = 0;
  sub {
    my $k = hashKey @_;
    my $j = 0;
    if (exists $a{$k}) {
      $j = $a{$k};
    } else {
      $a{$k} = ($j = $i++);
    }
    my $d = 0;
    if (@_ > 1) {
      my $last = $_[$#_];
      $d = $last eq 'Existing'     ? 1 :
           $last eq 'NonRetryable' ? 2 :
                                     0 ;
    }
    10000 + $d * 1000 + $j;
  }
}

BEGIN {
  *genSqlCode_ = genSqlCode;
}

sub reorderSqlCode {
  my $genSqlCode = genSqlCode;
  my $f = sub {
    my $d = substr ($_[1], 1, 1);
    my @d = $d eq '1' ? ('Existing')     :
            $d eq '2' ? ('NonRetryable') :
                        ()               ;
    $_[0] . $genSqlCode->($_[1], @d)
  };
  $_[0] =~ s/
    (
      (?:signal\s+sqlstate\s+'45100'.+?set.+?mysql_errno\s*=\s*) |
      (?:set\s+lastSqlCode\s*=\s*)
    )
    (1[0-9]{4})
  /
    $f->($1, $2)/xisgre;
}

sub Raise_ {
ltrim trim1 ("
  set lastSqlCode = $_[0];
  set lastMsgTxt = '$_[1]';
  leave XXX;
")
}

sub Raise { Raise_ (genSqlCode_ (@_), $_[0]) }

sub RaiseE { Raise @_, 'Existing' }

sub RaiseNr { Raise @_, 'NonRetryable' }

sub RaiseOnErr {
  my ($op, $k) = @_;
  my $s = '  ' . Raise_ (genSqlCode_ (@_), "$op $k failed");
  "if err then\n$s\nend if;"
}

sub Warn_ { "select 'Warn', chr(0x1f), concat('$ProcName 01000 20001 ', $_[0]);" }
sub Warn { Warn_ ("'$_[0]'") }

sub emptyParam { Raise_ '20003', "Empty $_[0]" }

sub valParam {
  my @Param = @_;
  my $h = sub {
    my $i = $_[0] + 1;
    my $Param_ = $Param[$i - 1];
    my $v_ = "param${i}Count";
    my $v = '@' . $v_;
    "set $v = (
  select count(*) from $Param_ where \$Id = \$Pid);\n\n" . RaiseOnErr ('Select', $v_) . q{

if } . $v . " < 1 then
  @{[emptyParam ($Param_)]}
end if;"
  };
  join "\n\n", map { $h->($_) } (0..$#_)
}

sub cleanupParam {
  my $s =
  join "\n", map {
q{set err = false;
delete from } . $_ . q{ where $Id = $Pid;
if not err then
  delete from Param where $Id = $Pid and ParamName = '} . $_ . q{';
end if;
}
  } @_;

"set gobble = true;

$s
set err = false;
set gobble = false;"
}

sub checkEmpty {
  my $Tbl = shift;
'if not exists (
  select 1 from ' . $Tbl . '
) then
  ' . Warn ("empty $Tbl") . '
  leave XXX;
end if;'
}

our $Val = {
  'null' => 'is null',
  'empty' => q{= ''},
  'neg' => '< 0',
};

sub valQry {
  my ($Tbl, $P, $limit) = @_;
  $limit = $limit // 1;
  my $limit_ = $limit ? "\nlimit\n  $limit" : '';
  my @s = ();
  my @where = ();
  for my $k (keys %$P) {
    my $v = $P->{$k};
    my $P_ = OrdHash;
    if (exists $Val->{$k}) {
      @{$P_}{map { "$k$_" } @$v} = map { "$_ $Val->{$k}" } @$v;
    } else {
      $P_->{$k} = $v;
    }
    push @s, map { "  ($P_->{$_}) as $_" } (keys %$P_);
    push @where, map { "  or ($_)" } (values %$P_);
  }
  $where[0] = ' ' x 4 . substr($where[0], 4);
qq{select
@{[join ",\n", @s]}
from
  $Tbl
where
@{[join "\n", @where]}$limit_
;
}
}

sub val {
  my $i = shift;
  valQry (@_) . "\n" . q{if (found_rows() > 0) then leave XXX; end if;}
}

sub valUniqQry {
  my ($Tbl, $Diff, $Col) = @_;
  ($Diff, $Col) = (toArr ($Diff), toArr ($Col));
qq{select 1
from $Tbl A, $Tbl B
where (
    @{[join "\n    or  ", map { "A.$_ <> B.$_"; } @$Diff]}
    )
  and (
    @{[join "\n    and ", map { "A.$_ = B.$_"; } @$Col]}
    )}
}

sub valUniq {
  my $i = shift;
  my ($Tbl, $Diff, $Col) = @_;
qq{if exists (
  @{[shr_ (2, valUniqQry (@_))]}
) then
  @{[RaiseE ('Duplicate (' . join (', ', @$Col) . ')')]}
end if;
}
}

our $Closing = q{until 1 end repeat;

set cont = false;
if @@in_transaction then
  if lastSqlCode = 0 then
    commit;
  else
    rollback;
  end if;
end if;};

our $End_ = trim1 q{
set cont = false;
if lastSqlCode <> 0 then
  signal sqlstate '45100'
    set mysql_errno = lastSqlCode, message_text = lastMsgTxt;
end if;

end;
};

our $End = $Closing . "\n\n" . $End_;

our %P_Db = ('BB' => BB, 'BBR' => BBR);

sub if_p_Db { join "\n", ("if p_Db & $P_Db{$_[0]} then", shr (2, $_[1]->($_[0])), 'end if;') }

sub hash_ { "md5_u64(concat(\n    @{[join qq{\n  , chr(0x1f)\n  , }, @_]}\n))" }

my $tpl = slurp $ARGV[0];
$ProcName = getProcName_ $tpl;

our $cont = 0;
our $viewBp = 0;

our $Boilerplate = view slurpp ('bp');

sub  Boilerplate {
  my $cont_ = $cont ? "\n\nset cont = true;" : '';
  my $view_ = $viewBp ? \&view : $I;
  $view_->($Boilerplate =~ s/^(XXX: repeat)/$1$cont_/mr)
}

my $f =
  $procOpt  && !$paramOpt ? \&eraseParam :
  !$procOpt && $paramOpt  ? \&eraseProc  :
                            $I           ;

print trim reorderSqlCode $f->(view ($tpl));
