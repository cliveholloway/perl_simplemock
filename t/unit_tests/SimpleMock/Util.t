use Test::Most;
use Data::Dumper;
use TestModule;

use SimpleMock::Util qw(
  all_file_subs
  generate_args_sha
  namespace_from_file
);

my @all_subs = sort ( all_file_subs('TestModule.pm') );
is_deeply(
  \@all_subs,
  [
    'run_db_query',
    'sub_five',
    'sub_four',
    'sub_one',
    'sub_six',
    'sub_three',
    'sub_two',
  ],
  'all_file_subs() returns all subs in file'
);

my $static_args_sha1 = generate_args_sha([1,2]);
is $static_args_sha1, '49a64717d5d4cb19952e6eac2946415cf6879adacf9908e7d872332d32c6e684', 'generate_args_sha for static args';
my $static_args_sha2 = generate_args_sha();
is $static_args_sha2, '_default', 'generate_args_sha for no args';

my $code_sha1 = generate_args_sha( sub { 1 } );
my $code_sha2 = generate_args_sha( sub { 2 } );
is $code_sha1, $code_sha2, "generate_args_sha - code args make the same sha";

is namespace_from_file('TestModule/Util.pm'), 'TestModule::Util',
    'namespace_from_file() returns the correct namespace';

done_testing();

1;
