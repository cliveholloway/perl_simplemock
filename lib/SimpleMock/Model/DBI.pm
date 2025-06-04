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

our $DBI_MOCKS;

our $drh = DBI->install_driver('SimpleMock');

our @valid_global_meta_keys = (
    # 0|1 allow queries that are not mocked to run with a default empty result set
    'allow_unmocked_queries',
);
our %valid_global_meta_keys_lookup;
undef @valid_global_meta_keys_lookup{ @valid_global_meta_keys };

BEGIN {
    use DBI;
    no warnings 'redefine';

    my $orig_connect = \&DBI::connect;

    # force DBI connect to use dbd:SimpleMock
    *DBI::connect = sub {
        my ($class, undef, undef, undef, $attr) = @_;
        return $orig_connect->($class, 'dbi:SimpleMock:', undef, undef, $attr);
    };
}

# lowercase and remove double spaces - I know some DBs are case sensitive, but
# this can simplify catching typos in tests
sub _normalize_query {
    my ($query) = @_;
    $query = lc($query);
    $query =~ s/ +/ /g;
    return $query;
}

sub register_mocks {
    my $mocks_data = shift;

    my $meta = $mocks_data->{META} || {};
    # only one option initially, but add more as needed
    META: foreach my $key (keys %$meta) {
        die "unknown meta key: $key" unless exists $valid_global_meta_keys_lookup{$key};
        $DBI_MOCKS->{_meta}->{$key} = $meta->{$key};
    }

    my $queries = $mocks_data->{QUERIES} || {};

    QUERY: foreach my $query (keys %$queries) {
        my $normalized_query = _normalize_query($query);
        MOCK: foreach my $mock (@{$queries->{$query}}) { 
            my $sha = generate_args_sha(delete $mock->{args});
            $DBI_MOCKS->{$normalized_query}->{$sha} = dclone($mock);
        }
    }
}

sub _get_mock_for {
    my ($query, $args) = @_;
    my $normalized_query = _normalize_query($query);
    my $sha = generate_args_sha($args);
    my $mock = $DBI_MOCKS->{$normalized_query}->{$sha};
    unless ($mock->{data} || $DBI_MOCKS->{_meta}->{allow_unmocked_queries}) {
        die "No mock data found for query: '$query' with args: " . Dumper($args);
    }
    $mock->{data} //= [[]];

    return dclone($mock);
}

1;
