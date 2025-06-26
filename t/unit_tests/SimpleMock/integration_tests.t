#!/usr/bin/perl
use strict;
use warnings;
use Test::Most;
use SimpleMock qw(register_mocks);
use TestModule;

# Test cross-model integration scenarios

################################################################################
# SUBS + DBI Integration
################################################################################

# Create a mock function that uses database operations internally
register_mocks(
    SUBS => {
        'TestModule' => {
            'complex_data_operation' => [
                { args => ['user_data'], returns => sub { 
                    # This mock simulates a function that would normally query the database
                    my $db_result = TestModule::run_db_query('C%');
                    return "Processed " . scalar(@$db_result) . " records";
                }}
            ]
        }
    },
    DBI => {
        QUERIES => [
            {
                sql => 'SELECT name, email FROM user where name like=?',
                results => [
                    { args => ['C%'], data => [['Clive', 'clive@test.com'], ['Colin', 'colin@test.com']] }
                ]
            }
        ]
    }
);

my $result = TestModule::complex_data_operation('user_data');
is $result, 'Processed 2 records', 'SUBS mock calling DBI mock works';

################################################################################
# SUBS + LWP Integration  
################################################################################

# Mock a function that makes HTTP requests
register_mocks(
    SUBS => {
        'TestModule' => {
            'api_wrapper' => [
                { args => ['get_user'], returns => sub {
                    my $response = TestModule::fetch_url('http://api.example.com/user');
                    return "API returned: " . $response->content;
                }}
            ]
        }
    },
    LWP => {
        'http://api.example.com/user' => {
            'GET' => [
                { response => 'User data from API' }
            ]
        }
    }
);

my $api_result = TestModule::api_wrapper('get_user');
is $api_result, 'API returned: User data from API', 'SUBS mock calling LWP mock works';

################################################################################
# DBI + LWP Integration
################################################################################

# Test scenario where database operations might trigger HTTP calls 
# (e.g., webhook notifications, API validations)
register_mocks(
    SUBS => {
        'TestModule' => {
            'process_with_notification' => [
                { returns => sub {
                    # Simulate: query database, then send notification
                    my $db_data = TestModule::run_db_query('A%');
                    my $notification = TestModule::fetch_url('http://webhook.example.com/notify');
                    return "Processed " . scalar(@$db_data) . " rows, notification: " . $notification->code;
                }}
            ]
        }
    },
    DBI => {
        QUERIES => [
            {
                sql => 'SELECT name, email FROM user where name like=?',
                results => [
                    { args => ['A%'], data => [['Alice', 'alice@test.com']] }
                ]
            }
        ]
    },
    LWP => {
        'http://webhook.example.com/notify' => {
            'GET' => [
                { response => { code => 200, content => 'OK' } }
            ]
        }
    }
);

my $combined_result = TestModule::process_with_notification();
is $combined_result, 'Processed 1 rows, notification: 200', 'Combined DBI + LWP operations work';

################################################################################
# Multiple Mock Registrations
################################################################################

# Test that multiple register_mocks calls accumulate properly
register_mocks(
    SUBS => {
        'TestModule' => {
            'first_function' => [{ returns => 'first' }]
        }
    }
);

register_mocks(
    SUBS => {
        'TestModule' => {
            'second_function' => [{ returns => 'second' }]
        }
    }
);

# Both functions should work after separate registrations
is TestModule::first_function(), 'first', 'First function mock works after separate registration';
is TestModule::second_function(), 'second', 'Second function mock works after separate registration';

################################################################################
# Mock Override Behavior
################################################################################

# Test that later registrations override earlier ones for the same function
register_mocks(
    SUBS => {
        'TestModule' => {
            'override_test' => [{ returns => 'original' }]
        }
    }
);

is TestModule::override_test(), 'original', 'Original mock value works';

register_mocks(
    SUBS => {
        'TestModule' => {
            'override_test' => [{ returns => 'overridden' }]
        }
    }
);

is TestModule::override_test(), 'overridden', 'Mock override works correctly';

################################################################################
# Complex Argument Matching Across Models
################################################################################

# Test complex scenarios with multiple argument patterns
register_mocks(
    SUBS => {
        'TestModule' => {
            'multi_pattern_function' => [
                { args => ['database'], returns => sub {
                    TestModule::run_db_query('D%');
                    return 'database_path';
                }},
                { args => ['http'], returns => sub {
                    TestModule::fetch_url('http://test.example.com');
                    return 'http_path';
                }},
                { returns => 'default_path' }
            ]
        }
    },
    DBI => {
        QUERIES => [
            {
                sql => 'SELECT name, email FROM user where name like=?',
                results => [
                    { args => ['D%'], data => [['Dave', 'dave@test.com']] }
                ]
            }
        ]
    },
    LWP => {
        'http://test.example.com' => {
            'GET' => [
                { response => 'Test response' }
            ]
        }
    }
);

is TestModule::multi_pattern_function('database'), 'database_path', 'Database branch of complex function works';
is TestModule::multi_pattern_function('http'), 'http_path', 'HTTP branch of complex function works';
is TestModule::multi_pattern_function('other'), 'default_path', 'Default branch of complex function works';

done_testing();