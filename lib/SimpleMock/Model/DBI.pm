package SimpleMock::Model::DBI;
use strict;
use warnings;
use DBI;
use DBD::Mock;
use Scalar::Util qw(blessed);
use Storable qw(dclone);
use Data::Dumper;

use SimpleMock::Util qw(
  generate_args_sha
);

our $VERSION = '0.01';

our $DBI_MOCKS;

our $drh = DBI->install_driver('SimpleMock');

our @valid_global_meta_keys = (
    # 0|1 allow queries that are not mocked to run with a default empty result set
    'allow_unmocked_queries',

    # 0|1 if true, then $sth->execute returns undef (use for error checking tests)
    'execute_fail',

    # 0|1 if true, then $dbh->connect returns undef (use for error checking tests)
    'connect_fail',

    # 0|1 if true, then $dbh->prepare fails with invalid SQL error
    'prepare_fail',
);
our %valid_global_meta_keys_lookup;
undef @valid_global_meta_keys_lookup{ @valid_global_meta_keys };

# lowercase and remove double spaces - I know some DBs are case sensitive, but
# this can simplify catching typos in tests
sub _normalize_sql {
    my ($sql) = @_;
    $sql = lc($sql);
    $sql =~ s/ +/ /g;
    return $sql;
}

sub register_mocks {
    my $mocks_data = shift;

    my $meta = $mocks_data->{META} || {};
    # only one option initially, but add more as needed
    META: foreach my $key (keys %$meta) {
        die "unknown meta key: $key" unless exists $valid_global_meta_keys_lookup{$key};
        $DBI_MOCKS->{_meta}->{$key} = $meta->{$key};
    }

    my $queries = $mocks_data->{QUERIES} || [];

    QUERY: foreach my $query (@$queries) {
        my $normalized_sql = _normalize_sql($query->{sql});
        my $cols = $query->{cols} || [];
        RESULT: foreach my $result (@{$query->{results} || []}) {
            my $data = $result->{data} || [[]];
            my $sha = generate_args_sha($result->{args});
            my $mock = {
                data => $data,
                cols => $cols,
                args => $result->{args} || [],
            };
            $DBI_MOCKS->{$normalized_sql}->{$sha} = dclone($mock);
        }
    }
}

sub _get_mock_for {
    my ($sql, $args) = @_;
    my $normalized_sql = _normalize_sql($sql);
    my $sha = generate_args_sha($args);
    my $mock = $DBI_MOCKS->{$normalized_sql}->{$sha} || $DBI_MOCKS->{$normalized_sql}->{'_default'};
    unless ($mock->{data} || $DBI_MOCKS->{_meta}->{allow_unmocked_queries}) {
        die "No mock data found for query: '$normalized_sql' with args: " . Dumper($args);
    }
    $mock->{data} //= [[]];

    return dclone($mock);
}

1;

=HEAD1 NAME

SimpleMock::Model::DBI - A mock model for DBI queries

=head1 DESCRIPTION

This module provides a mock model for DBI queries, allowing you to register
mock queries and their results. It normalizes queries and handles argument-based mocking.

Meta data can be set to control behavior such as allowing unmocked queries, or to force
failure on certain operations like i`prepare`, `execute` or `connect`.

=head1 USAGE

You probably won't want to use this module directly, but rather use the SimpleMock
module in your tests instead:

    use SimpleMock qw(register_mocks);

    register_mocks({
        DBI => {
            QUERIES => [
                { sql => 'SELECT name, email FROM users WHERE id = ?',
                  results => [ 
                    { args => [1], data => [ [arrayref, of], [array, refs] ] },
                    { args => [2], data => [ [another, arrayref], [of, arrayrefs] ] },
                    { data => [ [default, arrayref], [of, arrayrefs] ] },
                ],
            ],
        },
    });

For each query, specify the SQL statement, the expected arguments, and the data to return.

If you omit the `args` field, it will return this data for any arguments that do not match.

=cut
