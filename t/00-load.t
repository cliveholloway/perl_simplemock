use Test::More;

# List all modules that should load
my @modules = qw(
    SimpleMock
    SimpleMock::Util
    SimpleMock::Model::DBI
    SimpleMock::Model::LWP
    SimpleMock::Mocks::DBI
    SimpleMock::Mocks::LWP
    DBD::SimpleMock
);

foreach my $mod (@modules) {
    use_ok($mod) or diag "Couldn't load $mod";
}

ok 0, 'failing';

done_testing;

