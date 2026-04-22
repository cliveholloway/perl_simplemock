#!/usr/bin/perl
use strict;
use warnings;
use Test::Most;

# Comprehensive test runner to check all our new tests

my @test_files = (
    't/unit_tests/SimpleMock.t',
    't/unit_tests/SimpleMock/Util.t',
    't/unit_tests/SimpleMock/Model/SUBS.t',
    't/unit_tests/SimpleMock/Model/DBI.t',
    't/unit_tests/SimpleMock/Model/LWP.t',
    't/unit_tests/SimpleMock/error_handling.t',
    't/unit_tests/SimpleMock/boundary_tests.t',
    't/unit_tests/SimpleMock/integration_tests.t',
    't/unit_tests/SimpleMock/performance_tests.t',
    't/unit_tests/SimpleMock/model_specific_tests.t',
);

my $total_tests = 0;
my $failed_tests = 0;

print "Running comprehensive test suite...\n\n";

for my $test_file (@test_files) {
    print "Running $test_file...\n";
    
    my $result = system("cd /home/runner/work/perl_simplemock/perl_simplemock && PERL5LIB=lib:t/lib perl $test_file");
    
    if ($result == 0) {
        print "✓ PASSED\n";
    } else {
        print "✗ FAILED\n";
        $failed_tests++;
    }
    
    $total_tests++;
    print "\n";
}

print "="x50 . "\n";
print "Test Summary:\n";
print "Total tests run: $total_tests\n";
print "Passed: " . ($total_tests - $failed_tests) . "\n";
print "Failed: $failed_tests\n";

if ($failed_tests == 0) {
    print "All tests PASSED! ✓\n";
    exit 0;
} else {
    print "Some tests FAILED! ✗\n";
    exit 1;
}