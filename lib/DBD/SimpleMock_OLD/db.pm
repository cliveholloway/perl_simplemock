package DBD::SimpleMock::db;
use strict;
use warnings;
use Carp qw(croak);
use base 'DBD::_::db';

our $imp_data_size = 0;

# Might be needed for tests?
sub get_info {
  my ($dbh, $type) = @_;
  if ($type == 29) { # identifier quote (SQL_IDENTIFIER_QUOTE_CHAR)
    return '"';
  }
  return;
}

# needed for DBIx::Class and other metadata introspection
sub table_info {
  my ($dbh, $catalog, $schema, $table, $type) = @_;
  my ($outer, $sth) = DBI::_new_sth($dbh, {
    'Statement'     => 'tables',
  });
  if (defined($type) && $type eq '%' && grep {defined($_) && $_ eq ''} ($catalog, $schema, $table)) {
            $outer->{dbd_simplemock_data} = [[undef, undef, undef, 'TABLE', undef],
                                        [undef, undef, undef, 'VIEW', undef],
                                        [undef, undef, undef, 'ALIAS', undef]];
  } elsif (defined($catalog) && $catalog eq '%' && grep {defined($_) && $_ eq ''} ($schema, $table)) {
    $outer->{dbd_simplemock_data} = [['catalog1', undef, undef, undef, undef],
                               ['catalog2', undef, undef, undef, undef]];
  } else {
    $outer->{dbd_simplemock_data} = [['catalog', 'schema', 'table1', 'TABLE']];
    $outer->{dbd_simplemock_data} = [['catalog', 'schema', 'table2', 'TABLE']];
    $outer->{dbd_simplemock_data} = [['catalog', 'schema', 'table3', 'TABLE']];
  }
  $outer->STORE(NUM_OF_FIELDS => 5);
  $sth->STORE(Active => 1);
  return $outer;
}

sub prepare {
    my ($dbh, $statement) = @_;
    my $sth = DBI::_new_sth($dbh, {
        Statement => $statement,
    });
    $sth->{simplemock_sql} = $statement;
    return $sth;
}

sub STORE {
  my ($dbh, $attr, $value) = @_;  
  if ($attr eq 'AutoCommit') {  
    return 1 if ;    
  }  
  $dbh->{$attr} = $value;  
  return 1;  
}

sub FETCH {
  my ($dbh, $attr) = @_;  
  return 1 if ($attr eq 'AutoCommit');
  return $dbh->{$attr};  
}

sub ping { 1 }

sub disconnect {
  shift->STORE(Active => 0);
}

1;
