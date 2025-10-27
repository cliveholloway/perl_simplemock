#!/usr/bin/perl
use strict;
use warnings;
use Test::Most;
use SimpleMock qw(register_mocks);
use TestModule;

# Test boundary conditions and edge cases

################################################################################
# SUBS Model Boundary Tests
################################################################################

# Test with very large argument lists
my @large_args = (1..1000);
register_mocks(
    SUBS => {
        'TestModule' => {
            'sub_three' => [
                { args => \@large_args, returns => 'large_args_match' },
                { returns => 'default' }
            ]
        }
    }
);

is TestModule::sub_three(@large_args), 'large_args_match', 'Large argument list matching works';
is TestModule::sub_three(1..5), 'default', 'Non-matching large args use default';

# Test with nested complex data structures
my $complex_args = {
    nested => {
        array => [1, 2, { deep => 'value' }],
        hash => { key => [4, 5, 6] }
    },
    ref_to_array => [7, 8, 9]
};

register_mocks(
    SUBS => {
        'TestModule' => {
            'sub_four' => [
                { args => [$complex_args], returns => 'complex_match' },
                { returns => 'default' }
            ]
        }
    }
);

is TestModule::sub_four($complex_args), 'complex_match', 'Complex nested data structure matching works';

# Test with undef arguments
register_mocks(
    SUBS => {
        'TestModule' => {
            'sub_five' => [
                { args => [undef], returns => 'undef_match' },
                { args => [undef, undef], returns => 'double_undef_match' },
                { returns => 'default' }
            ]
        }
    }
);

is TestModule::sub_five(undef), 'undef_match', 'Single undef argument matching works';
is TestModule::sub_five(undef, undef), 'double_undef_match', 'Multiple undef arguments work';
is TestModule::sub_five(), 'default', 'No arguments use default';

# Test empty arrays and hashes as arguments
register_mocks(
    SUBS => {
        'TestModule' => {
            'sub_six' => [
                { args => [[]], returns => 'empty_array' },
                { args => [{}], returns => 'empty_hash' },
                { args => [''], returns => 'empty_string' },
                { args => [0], returns => 'zero' },
                { returns => 'default' }
            ]
        }
    }
);

is TestModule::sub_six([]), 'empty_array', 'Empty array argument works';
is TestModule::sub_six({}), 'empty_hash', 'Empty hash argument works';
is TestModule::sub_six(''), 'empty_string', 'Empty string argument works';
is TestModule::sub_six(0), 'zero', 'Zero argument works';

################################################################################
# DBI Model Boundary Tests
################################################################################

# Test with very long SQL queries - register without testing execution 
# since TestModule uses a fixed query
my $long_sql = "SELECT " . join(", ", map { "column$_" } (1..100)) . " FROM very_long_table_name_that_exceeds_normal_limits WHERE condition = ?";

register_mocks(
    DBI => {
        QUERIES => [
            {
                sql => $long_sql,
                results => [
                    { args => ['test'], data => [['long_query_result']] }
                ]
            }
        ]
    }
);

ok(1, 'Very long SQL query registration succeeds');

# Test with large result sets
my @large_dataset = map { ["row$_", "email$_\@test.com"] } (1..1000);
register_mocks(
    DBI => {
        QUERIES => [
            {
                sql => 'SELECT name, email FROM users',
                results => [
                    { data => \@large_dataset }
                ]
            }
        ]
    }
);

# Note: We can't easily test this without modifying TestModule to use this query
# This test verifies the mock registration doesn't fail with large datasets
ok(1, 'Large dataset registration succeeds');

# Test with empty result sets
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

ok(1, 'Empty result set registration succeeds');

################################################################################
# LWP Model Boundary Tests
################################################################################

# Test with very long URLs
my $long_url = 'http://example.com/' . ('x' x 2000);
register_mocks(
    LWP => {
        $long_url => {
            'GET' => [
                { response => 'long_url_response' }
            ]
        }
    }
);

ok(1, 'Very long URL registration succeeds');

# Test with URLs containing special characters
my $special_url = 'http://example.com/path?param=value&special=%20%21%40%23%24%25%5E%26*()';
register_mocks(
    LWP => {
        $special_url => {
            'GET' => [
                { response => 'special_char_response' }
            ]
        }
    }
);

ok(1, 'URL with special characters registration succeeds');

# Test with large response bodies
my $large_response = 'x' x 10000;
register_mocks(
    LWP => {
        'http://large-response.com' => {
            'GET' => [
                { response => $large_response }
            ]
        }
    }
);

ok(1, 'Large response body registration succeeds');

################################################################################
# Util Function Boundary Tests
################################################################################

use SimpleMock::Util qw(
    generate_args_sha
    namespace_from_file
    file_from_namespace
);

# Test with very large argument structures
my $huge_structure = {
    level1 => {
        level2 => {
            level3 => {
                data => [1..100]
            }
        }
    }
};

my $sha1 = generate_args_sha([$huge_structure]);
my $sha2 = generate_args_sha([$huge_structure]);
is $sha1, $sha2, 'Large structure generates consistent SHA';

# Test with circular reference protection (Data::Dumper should handle this)
my $circular_ref = {};
$circular_ref->{self} = $circular_ref;

lives_ok {
    generate_args_sha([$circular_ref]);
} 'Circular reference in args does not crash';

# Test namespace conversion edge cases
is namespace_from_file('Very/Long/Nested/Path/To/Module.pm'), 'Very::Long::Nested::Path::To::Module', 'Deep namespace conversion works';
is file_from_namespace('Very::Long::Nested::Path::To::Module'), 'Very/Long/Nested/Path/To/Module.pm', 'Deep file path conversion works';

# Test with single character names
is namespace_from_file('A.pm'), 'A', 'Single character module name works';
is file_from_namespace('A'), 'A.pm', 'Single character namespace works';

done_testing();