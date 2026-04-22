#!/usr/bin/perl
use strict;
use warnings;
use Test::Most;
use Time::HiRes qw(time);
use SimpleMock qw(register_mocks);
use TestModule;

# Performance and stress tests for SimpleMock framework

################################################################################
# Mock Registration Performance
################################################################################

# Test performance of registering many mocks
my $start_time = time();

# Register 100 different mocked functions
my %large_mock_set;
for my $i (1..100) {
    $large_mock_set{"function_$i"} = [
        { args => ["arg_$i"], returns => "result_$i" },
        { returns => "default_$i" }
    ];
}

register_mocks(
    SUBS => {
        'TestModule' => \%large_mock_set
    }
);

my $registration_time = time() - $start_time;
ok($registration_time < 1.0, "Registration of 100 mocks completes in reasonable time (${registration_time}s)");

################################################################################
# Mock Execution Performance
################################################################################

# Test performance of mock lookups with many registered mocks
$start_time = time();

for my $i (1..100) {
    my $result = TestModule->can("function_$i")->("arg_$i");
    is($result, "result_$i", "Mock function_$i returns correct result") if $i <= 5; # Only test first 5 for output brevity
}

my $execution_time = time() - $start_time;
ok($execution_time < 1.0, "Execution of 100 mock calls completes in reasonable time (${execution_time}s)");

################################################################################
# Argument Hashing Performance
################################################################################

use SimpleMock::Util qw(generate_args_sha);

# Test performance with various argument sizes
my @test_cases = (
    { name => 'small_args', args => [1, 2, 3] },
    { name => 'medium_args', args => [1..100] },
    { name => 'large_args', args => [1..1000] },
    { name => 'complex_structure', args => [{ map { $_ => [1..$_] } (1..50) }] }
);

for my $test_case (@test_cases) {
    $start_time = time();
    
    # Generate SHA for the same args multiple times
    my @shas;
    for (1..100) {
        push @shas, generate_args_sha($test_case->{args});
    }
    
    my $hash_time = time() - $start_time;
    
    # Verify all SHAs are identical
    my $first_sha = $shas[0];
    my $all_same = 1;
    for my $sha (@shas) {
        if ($sha ne $first_sha) {
            $all_same = 0;
            last;
        }
    }
    
    ok($all_same, "All SHA hashes identical for $test_case->{name}");
    ok($hash_time < 1.0, "SHA generation for $test_case->{name} completes in reasonable time (${hash_time}s)");
}

################################################################################
# Memory Usage Stress Test  
################################################################################

# Test with large mock data structures
my @large_response_data = map {
    {
        id => $_,
        name => "User $_",
        email => "user$_\@example.com", 
        metadata => {
            created => "2024-01-$_",
            active => $_ % 2,
            preferences => [ map { "pref_$_" } (1..10) ]
        }
    }
} (1..1000);

register_mocks(
    SUBS => {
        'TestModule' => {
            'get_large_dataset' => [
                { returns => sub { return \@large_response_data } }
            ]
        }
    }
);

my $large_data = TestModule::get_large_dataset();
is(scalar(@$large_data), 1000, "Large dataset mock returns correct size");
is($large_data->[0]->{name}, "User 1", "Large dataset structure is correct");

################################################################################
# Concurrent Access Simulation
################################################################################

# Test rapid successive calls to the same mock
register_mocks(
    SUBS => {
        'TestModule' => {
            'rapid_fire_function' => [
                { args => ['ping'], returns => 'pong' },
                { returns => 'default' }
            ]
        }
    }
);

$start_time = time();
my @results;
for (1..1000) {
    push @results, TestModule::rapid_fire_function('ping');
}
my $rapid_fire_time = time() - $start_time;

is(scalar(@results), 1000, "Rapid fire calls return correct count");
is($results[0], 'pong', "Rapid fire calls return correct value");
is($results[999], 'pong', "Rapid fire calls maintain consistency");
ok($rapid_fire_time < 2.0, "1000 rapid calls complete in reasonable time (${rapid_fire_time}s)");

################################################################################
# DBI Performance Tests
################################################################################

# Test with many DBI queries
my @many_queries;
for my $i (1..50) {
    push @many_queries, {
        sql => "SELECT * FROM table_$i WHERE id = ?",
        results => [
            { args => [$i], data => [["result_$i"]] }
        ]
    };
}

$start_time = time();
register_mocks(
    DBI => {
        QUERIES => \@many_queries
    }
);
my $dbi_registration_time = time() - $start_time;

ok($dbi_registration_time < 1.0, "Registration of 50 DBI queries completes quickly (${dbi_registration_time}s)");

################################################################################
# LWP Performance Tests
################################################################################

# Test with many URL patterns
my %many_urls;
for my $i (1..50) {
    $many_urls{"http://api$i.example.com"} = {
        'GET' => [{ response => "Response from API $i" }]
    };
}

$start_time = time();
register_mocks(
    LWP => \%many_urls
);
my $lwp_registration_time = time() - $start_time;

ok($lwp_registration_time < 1.0, "Registration of 50 LWP URLs completes quickly (${lwp_registration_time}s)");

################################################################################
# Stress Test: Mixed Operations
################################################################################

# Simulate a complex application workflow with mixed operations
my %workflow_lwp_mocks;
for my $i (1..5) {
    $workflow_lwp_mocks{"http://workflow$i.test.com"} = {
        'GET' => [{ response => "Data from workflow API $i" }]
    };
}

register_mocks(
    SUBS => {
        'TestModule' => {
            'complex_workflow' => [
                { returns => sub {
                    my @steps;
                    
                    # Step 1: Database query
                    my $db_result = TestModule::run_db_query('workflow%');
                    push @steps, "DB: " . scalar(@$db_result) . " rows";
                    
                    # Step 2: Multiple API calls
                    for my $api_num (1..5) {
                        my $response = TestModule::fetch_url("http://workflow$api_num.test.com");
                        push @steps, "API$api_num: " . length($response->content) . " chars";
                    }
                    
                    return join('; ', @steps);
                }}
            ]
        }
    },
    DBI => {
        QUERIES => [
            {
                sql => 'SELECT name, email FROM user where name like=?',
                results => [
                    { args => ['workflow%'], data => [['workflow_user', 'workflow@test.com']] }
                ]
            }
        ]
    },
    LWP => \%workflow_lwp_mocks
);

$start_time = time();
my $workflow_result = TestModule::complex_workflow();
my $workflow_time = time() - $start_time;

like($workflow_result, qr/DB: 1 rows/, "Complex workflow includes database step");
like($workflow_result, qr/API1: \d+ chars/, "Complex workflow includes API steps");
ok($workflow_time < 1.0, "Complex workflow completes in reasonable time (${workflow_time}s)");

done_testing();