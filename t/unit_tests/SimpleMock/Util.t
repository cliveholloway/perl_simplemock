use Test::Most;
use Data::Dumper;
use TestModule;
use TestModule2;

use SimpleMock::Util qw(
  all_file_subs
  generate_args_sha
  namespace_from_file
  file_from_namespace
);

my @all_subs = sort ( all_file_subs('TestModule2.pm') );
is_deeply(
  \@all_subs,
  [
    'one',
    'two',
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

is file_from_namespace('TestModule::Util'), 'TestModule/Util.pm',
    'file_from_namespace() returns the correct file path';

done_testing();

1;
