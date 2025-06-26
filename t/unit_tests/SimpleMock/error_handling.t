#!/usr/bin/perl
use strict;
use warnings;
use Test::Most;
use SimpleMock qw(register_mocks);
use TestModule;

# Test comprehensive error handling scenarios across all models

################################################################################
# SUBS Model Error Handling
################################################################################

# Test invalid model registration
dies_ok { 
    register_mocks(invalid_model => {}) 
} 'Invalid model name should die';

dies_ok { 
    register_mocks('lower_case_model' => {}) 
} 'Lower case model name should die';

dies_ok { 
    register_mocks('INVALID-NAME' => {}) 
} 'Model name with hyphens should die';

# Test invalid namespace loading - this actually succeeds because
# SUBS model allows creating mocks for modules not yet loaded
lives_ok { 
    register_mocks(
        SUBS => {
            'NonExistent::Module' => {
                'some_sub' => [{ returns => 'test' }]
            }
        }
    ) 
} 'Non-existent module is allowed in SUBS model';

# Test malformed mock data
dies_ok { 
    register_mocks(
        SUBS => {
            'TestModule' => {
                'sub_one' => "not_an_array"  # should be array of mock specs
            }
        }
    ) 
} 'Malformed SUBS mock data should die';

################################################################################
# DBI Model Error Handling  
################################################################################

# Test invalid META keys
dies_ok {
    register_mocks(
        DBI => {
            META => {
                'invalid_meta_key' => 1
            }
        }
    )
} 'Invalid DBI META key should die';

# Test malformed SQL queries
lives_ok {
    register_mocks(
        DBI => {
            QUERIES => [
                {
                    sql => '',  # empty SQL
                    results => [{ data => [] }]
                }
            ]
        }
    )
} 'Empty SQL should not die during registration';

# Test invalid query results structure
dies_ok {
    register_mocks(
        DBI => {
            QUERIES => [
                {
                    sql => 'SELECT * FROM test',
                    results => "not_an_array"  # should be array
                }
            ]
        }
    )
} 'Invalid query results structure should die';

################################################################################
# LWP Model Error Handling
################################################################################

# Test malformed URL structure
lives_ok {
    register_mocks(
        LWP => {
            'not-a-valid-url' => {
                'GET' => [{ response => 'test' }]
            }
        }
    )
} 'Invalid URL format should not die during registration';

# Test invalid HTTP method
lives_ok {
    register_mocks(
        LWP => {
            'http://test.com' => {
                'INVALID_METHOD' => [{ response => 'test' }]
            }
        }
    )
} 'Invalid HTTP method should not die during registration';

################################################################################
# Util Function Error Handling
################################################################################

use SimpleMock::Util qw(
    all_file_subs
    generate_args_sha
    namespace_from_file
    file_from_namespace
);

# Test all_file_subs with unloaded file
dies_ok {
    all_file_subs('NonExistent/Module.pm')
} 'all_file_subs should die for unloaded file';

# Test generate_args_sha with multiple arguments (should die)
dies_ok {
    generate_args_sha([1,2], "extra_arg")
} 'generate_args_sha should die with extra arguments';

# Test namespace conversion with empty input
is namespace_from_file(''), '', 'Empty file path should return empty namespace';
is file_from_namespace(''), '.pm', 'Empty namespace should return .pm';

# Test with undef input (should not crash)
lives_ok {
    namespace_from_file(undef)
} 'namespace_from_file should handle undef gracefully';

lives_ok {
    file_from_namespace(undef)  
} 'file_from_namespace should handle undef gracefully';

done_testing();