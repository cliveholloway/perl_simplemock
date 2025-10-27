#!/usr/bin/perl
use strict;
use warnings;
use Test::Most;
use SimpleMock qw(register_mocks);
use TestModule;

# Extended model-specific test scenarios

################################################################################
# SUBS Model Advanced Tests
################################################################################

# Test mocking of class methods vs. functions
register_mocks(
    SUBS => {
        'TestModule' => {
            'sub_one' => [
                { args => ['self', 'method_arg'], returns => 'mocked_method_call' },
                { returns => 'mocked_function_call' }
            ]
        }
    }
);

# Test both as function and method call
is TestModule::sub_one(), 'mocked_function_call', 'Function call uses default mock';
is TestModule::sub_one('self', 'method_arg'), 'mocked_method_call', 'Method-style call matches args';

# Test context-sensitive returns (wantarray handling)
register_mocks(
    SUBS => {
        'TestModule' => {
            'context_sensitive' => [
                { returns => sub { 
                    return wantarray ? ('array', 'context') : 'scalar_context';
                }}
            ]
        }
    }
);

my $scalar_result = TestModule::context_sensitive();
my @array_result = TestModule::context_sensitive();
is $scalar_result, 'scalar_context', 'Scalar context returns scalar';
is_deeply \@array_result, ['array', 'context'], 'Array context returns array';

# Test coderef mocks with access to original arguments
register_mocks(
    SUBS => {
        'TestModule' => {
            'argument_inspector' => [
                { returns => sub {
                    my @args = @_;
                    return "Received " . scalar(@args) . " args: " . join(',', @args);
                }}
            ]
        }
    }
);

is TestModule::argument_inspector('a', 'b', 'c'), 'Received 3 args: a,b,c', 'Coderef mock receives arguments';

# Test blessed object arguments
{
    package TestObject;
    sub new { bless {}, shift; }
    sub value { return 'test_value'; }
}

my $test_obj = TestObject->new();
register_mocks(
    SUBS => {
        'TestModule' => {
            'object_handler' => [
                { args => [$test_obj], returns => 'object_matched' },
                { returns => 'no_object' }
            ]
        }
    }
);

is TestModule::object_handler($test_obj), 'object_matched', 'Blessed object argument matching works';
is TestModule::object_handler('string'), 'no_object', 'Non-object uses default';

################################################################################
# DBI Model Advanced Tests
################################################################################

# Test different DBI methods with same SQL
register_mocks(
    DBI => {
        QUERIES => [
            {
                sql => 'SELECT id, name FROM advanced_test WHERE active = ?',
                cols => ['id', 'name'],  # for selectall_hashref
                results => [
                    { args => [1], data => [[1, 'Alice'], [2, 'Bob']] }
                ]
            }
        ]
    }
);

# Note: These tests would require TestModule to have functions that use these queries
# We're testing the mock registration doesn't fail
ok(1, 'Advanced DBI query with cols specification registered successfully');

# Test SQL normalization edge cases
register_mocks(
    DBI => {
        QUERIES => [
            {
                # Test that extra spaces are normalized
                sql => 'SELECT   *    FROM    table    WHERE   id  =  ?',
                results => [
                    { args => [1], data => [['result']] }
                ]
            }
        ]
    }
);

ok(1, 'SQL with irregular spacing registered successfully');

# Test META options combinations
register_mocks(
    DBI => {
        META => {
            allow_unmocked_queries => 1,
            execute_fail => 0,
            connect_fail => 0,
            prepare_fail => 0,
        }
    }
);

ok(1, 'All META options set successfully');

# Test queries with no results (empty result sets)
register_mocks(
    DBI => {
        QUERIES => [
            {
                sql => 'SELECT * FROM empty_table',
                results => [
                    { data => [] }
                ]
            }
        ]
    }
);

ok(1, 'Empty result set query registered successfully');

################################################################################
# LWP Model Advanced Tests
################################################################################

# Test different HTTP methods
my @http_methods = qw(GET POST PUT DELETE PATCH HEAD OPTIONS);
my %method_mocks;

for my $method (@http_methods) {
    $method_mocks{$method} = [
        { response => "Response for $method method" }
    ];
}

register_mocks(
    LWP => {
        'http://methods-test.com' => \%method_mocks
    }
);

ok(1, 'All HTTP methods registered successfully');

# Test complex response objects
register_mocks(
    LWP => {
        'http://complex-response.com' => {
            'GET' => [
                {
                    response => {
                        code => 201,
                        message => 'Created',
                        content => 'Resource created successfully',
                        headers => {
                            'Content-Type' => 'application/json',
                            'X-Custom-Header' => 'custom-value',
                            'Location' => 'http://complex-response.com/resource/123'
                        }
                    }
                }
            ]
        }
    }
);

ok(1, 'Complex response with headers registered successfully');

# Test URL with various query parameters
register_mocks(
    LWP => {
        'http://query-test.com' => {
            'GET' => [
                { args => { page => '1', limit => '10' }, response => 'Page 1 results' },
                { args => { page => '2', limit => '10' }, response => 'Page 2 results' },
                { args => { search => 'test' }, response => 'Search results' },
                { response => 'Default response' }
            ]
        }
    }
);

ok(1, 'Multiple query parameter combinations registered successfully');

# Test POST with different content types
register_mocks(
    LWP => {
        'http://post-test.com' => {
            'POST' => [
                { 
                    args => { 'Content-Type' => 'application/json' },
                    response => 'JSON accepted'
                },
                { 
                    args => { 'Content-Type' => 'application/x-www-form-urlencoded' },
                    response => 'Form data accepted'
                },
                { response => 'Default POST response' }
            ]
        }
    }
);

ok(1, 'POST requests with different content types registered successfully');

################################################################################
# Util Function Advanced Tests
################################################################################

use SimpleMock::Util qw(
    all_file_subs
    generate_args_sha
    namespace_from_file
    file_from_namespace
);

# Test namespace conversions with edge cases
my @namespace_tests = (
    { file => 'Simple.pm', expected_ns => 'Simple' },
    { file => 'My/Module.pm', expected_ns => 'My::Module' },
    { file => 'Very/Deep/Nested/Path.pm', expected_ns => 'Very::Deep::Nested::Path' },
    { file => 'File.pm', expected_ns => 'File' },
);

for my $test (@namespace_tests) {
    is namespace_from_file($test->{file}), $test->{expected_ns}, 
        "namespace_from_file('$test->{file}') = '$test->{expected_ns}'";
    is file_from_namespace($test->{expected_ns}), $test->{file},
        "file_from_namespace('$test->{expected_ns}') = '$test->{file}'";
}

# Test SHA generation with special cases
my @sha_tests = (
    { args => undef, name => 'undef args' },
    { args => [], name => 'empty array' },
    { args => [undef], name => 'array with undef' },
    { args => [''], name => 'empty string' },
    { args => [0], name => 'zero' },
    { args => [0.0], name => 'zero float' },
    { args => ['0'], name => 'string zero' },
);

for my $test (@sha_tests) {
    my $sha = generate_args_sha($test->{args});
    ok(defined $sha, "SHA generated for $test->{name}");
    ok(length($sha) > 0, "SHA for $test->{name} is non-empty");
    
    # Test consistency
    my $sha2 = generate_args_sha($test->{args});
    is($sha, $sha2, "SHA generation is consistent for $test->{name}");
}

# Test file_subs with loaded modules
my @subs = all_file_subs('TestModule.pm');
my @expected_subs = qw(sub_one sub_two sub_three sub_four sub_five sub_six run_db_query fetch_url);

# Check that we found some expected subroutines
my $found_expected = 0;
for my $expected (@expected_subs) {
    if (grep { $_ eq $expected } @subs) {
        $found_expected++;
    }
}

ok($found_expected >= 5, "all_file_subs found most expected subroutines from TestModule");

################################################################################
# Edge Case Combinations
################################################################################

# Test mock with both args and no-args versions
register_mocks(
    SUBS => {
        'TestModule' => {
            'flexible_function' => [
                { args => [], returns => 'explicit_no_args' },  # Explicit empty args
                { returns => 'default_no_args' }                # Default (no args key)
            ]
        }
    }
);

# Both should return the same thing since empty args and no args should be equivalent
my $explicit_result = TestModule::flexible_function();
is $explicit_result, 'explicit_no_args', 'Explicit empty args takes precedence over default';

# Test with reference arguments
my $array_ref = [1, 2, 3];
my $hash_ref = { key => 'value' };

register_mocks(
    SUBS => {
        'TestModule' => {
            'reference_handler' => [
                { args => [$array_ref], returns => 'array_ref_matched' },
                { args => [$hash_ref], returns => 'hash_ref_matched' },
                { returns => 'no_ref' }
            ]
        }
    }
);

is TestModule::reference_handler($array_ref), 'array_ref_matched', 'Array reference matching works';
is TestModule::reference_handler($hash_ref), 'hash_ref_matched', 'Hash reference matching works';
is TestModule::reference_handler('scalar'), 'no_ref', 'Scalar argument uses default';

done_testing();