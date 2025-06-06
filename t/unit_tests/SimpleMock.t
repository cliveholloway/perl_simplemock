# Start all Simplemock tests with these 4 lines!
use strict;
use warnings;
use Test::Most;
use SimpleMock qw(register_mocks);
# and then write your test as normal

use TestModule;

dies_ok { register_mocks(bad_model => {}); } "register mocks bad model";

################################################################################
# SUBS - see test for SimpleMock::Model::SUBS for more examples
################################################################################
my $r1 = TestModule::sub_one();
is $r1, 'one', 'Original test module return value';

lives_ok { register_mocks(
    SUBS => {
        'TestModule' => {
            'sub_three' => [
                { returns => 'default' },
                { args => [1], returns => 'one' },
            ]
        }
    }
); } "register mocks good model";

my $r2 = TestModule::sub_two();
is $r2, 'mocked', 'SimpleMock::Mocks::TestModule mock sub';

my $r3a = TestModule::sub_three(1);
is $r3a, 'one', 'register_mocks: test module return value for matched args';

my $r3b = TestModule::sub_three(2);
is $r3b, 'default', 'register_mocks: test module returns default value for no matched args';

my $r3c = TestModule::sub_three();
is $r3c, 'default', 'register_mocks: test module returns default value for no args';


################################################################################
# DBI - see test for SimpleMock::Model::DBI for more examples
################################################################################
my $d1 = [
    [ 'Clive', 'Clive@testme.com' ],
    [ 'Colin', 'Colin@testme.com' ],
];

my $d2 = [
    [ 'Jack', 'jack@testme.com' ],
    [ 'Jill', 'jill@testme.com' ],
]; 

register_mocks(
    DBI => {
        QUERIES => [
            {
                sql => 'SELECT name, email FROM user where name like=?',
                results => [
                    # for specific args
                    { args => [ 'C%' ], data => $d1 },
                    # default data to return
                    { data => $d2 },
                ],
            },
        ]
    }
);

my $data1 = TestModule::run_db_query('C%');
is_deeply $data1, $d1, 'DBI mock query with args';

# arg not found? use default
my $data2 = TestModule::run_db_query('J%');
is_deeply $data2, $d2, 'DBI mock query with no args';

################################################################################
# LWP - see test for SimpleMock::Model::LWP for more examples
################################################################################

register_mocks(
    LWP => {
        'http://example.com' => {
            GET => [
                { response => 'Example Content' },
            ],
        },
        'http://test.com' => {
            GET => [
                { response => {
                      content => 'Test Content',
                      code => 404,
                  }
                },
            ],
        },
    }
);

my $response1 = TestModule::fetch_url('http://example.com');
is $response1->content, 'Example Content', 'LWP mock request for example.com';
my $response2 = TestModule::fetch_url('http://test.com');
is $response2->content, 'Test Content', 'LWP mock request for test.com';
is $response2->code, 404, 'LWP mock request for test.com returns 404';

done_testing();

