package SimpleMock::Util;
use strict;
use warnings;
use Data::Dumper qw(Dumper);
use Exporter     qw(import);
use Digest::SHA  qw(sha256_hex);

our @EXPORT_OK = qw(
  all_file_subs
  generate_args_sha
  namespace_from_file
);

sub all_file_subs {
  my $file = shift;
  my $ns = namespace_from_file($file);
  my @subs = ();
  no strict 'refs';
  SYM: foreach my $sym (keys %{$ns.'::'}) {
    if (my $code_ref = *{$ns."::$sym"}{CODE}) {
      # ignore constants
      next SYM if (defined(prototype($code_ref)));
      push @subs, $sym
    }
  }
  return @subs;
}

# create sha for arg lists sent
sub generate_args_sha {
  my $args = shift;

  # make an empty hashref undef
  $args = undef unless $args && ref $args;

  # coderefs will be replaced with dummy markers safely, so disable warnings for this
  local $SIG{__WARN__} = sub {
    $_[0] =~ /^Encountered CODE ref/
      or warn $_[0];
  };
  
  local $Data::Dumper::Deepcopy=1;
  local $Data::Dumper::Indent=0;
  local $Data::Dumper::Purity=1;
  local $Data::Dumper::SortKeys=1;
  local $Data::Dumper::Terse=1;

  return defined $args ? sha256_hex(Dumper($args)) : '_default';
}

sub namespace_from_file {
  my $file = shift;
  $file =~ s/\.pm$//;
  $file =~ s/\//::/g;
  return $file;
}

1;
