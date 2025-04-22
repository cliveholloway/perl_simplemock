use Test::Most;
use Data::Dumper;
use TestModule;

use SimpleMock::Util qw(
  all_file_subs
  generate_args_sha
  file_from_namespace
  namespace_from_file
);

my @all_subs = sort ( all_file_subs('TestModule.pm') );

is_deeply(
  \@all_subs,
  [
    'sub_one',
    'sub_two',
  ],
  'all_file_subs() returns all subs in file'
);

my $static_args_sha = generate_args_sha(1,2);
is $static_args_sha, '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b', 'generate_args_sha for static args';

my $code_sha1 = generate_args_sha( sub { 1 } );
my $code_sha2 = generate_args_sha( sub { 2 } );
is $code_sha1, $code_sha2, "generate_args_sha - code args make the same sha";

is namespace_from_file('TestModule/Util.pm'), 'TestModule::Util',
    'namespace_from_file() returns the correct namespace';

done_testing();

1;
