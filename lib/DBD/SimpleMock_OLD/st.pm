package DBD::SimpleMock::st;
use strict;
use warnings;

our $imp_data_size = 0;

sub bind_param {
  my ($sth, $param, $value, $attr) = @_;
  $sth->{simplemock_bind}[$param - 1] = $value;
  return 1;
}

sub execute {
  my $sth = shift;
  my $sql = $sth->{simplemock_sql};
  my @bind = @{ $sth->{simplemock_bind} || [] };

use Data::Dumper;
warn Dumper({ SQL => $sql, BIND => \@bind });


  $sth->{simplemock_results} = [];

  $sth->{simplemock_pos} = 0;

  return 1;
}

sub fetchrow_arrayref {
  my $sth = shift;
  my $pos = $sth->{simplemock_pos}++;
  my $rows = $sth->{simplemock_results} || [];
  return undef if $pos >= @$rows;
  return $rows->[$pos];
}

sub fetchrow_hashref {
  my $sth = shift;
  my $row = $sth->fetchrow_arrayref or return undef;
  my @cols = @{ $sth->{simplemock_cols} };
  return { map { $cols[$_] => $row->[$_] } 0 .. $#cols };
}

*fetch = \&fetchrow_arrayref; # alias

sub FETCH {
  my ($sth, $attrib) = @_;
  return $sth->SUPER::FETCH($attrib);
}

sub STORE {
  my ($sth, $attrib, $value) = @_;
  return $sth->SUPER::STORE($attrib, $value);
}

1;
