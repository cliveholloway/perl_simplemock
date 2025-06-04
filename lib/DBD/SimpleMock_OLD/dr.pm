package DBD::SimpleMock::dr;
use strict;
use warnings;

our $imp_data_size = 0;

sub connect {
    my ($drh, @args) = @_;
    my $dbh = $drh->SUPER::connect(@args) or return;
    bless $dbh, 'DBD::SimpleMock::db';
    $dbh->STORE('Active', 1);
    $dbh->STORE('AutoCommit', 1);
    return $dbh;
}

sub DESTROY { undef }

1;
