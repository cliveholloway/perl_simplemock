package SimpleMock::Mocks::DBI;
use strict;
use warnings;

no warnings 'redefine';

our $VERSION = '0.01';
            
my $orig_connect = \&DBI::connect;
     
# force DBI connect to use dbd:SimpleMock
*DBI::connect = sub {
    my ($class, undef, undef, undef, $attr) = @_;
    return $orig_connect->($class, 'dbi:SimpleMock:', undef, undef, $attr);
};

1;
