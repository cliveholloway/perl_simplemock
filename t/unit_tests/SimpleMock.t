# Start all Simplemock tests with these 4 lines!
use strict;
use warnings;
use Test::Most;
use SimpleMock qw(register_mocks);
# and then write your test as normal

use TestModule;

my $r1 = TestModule::sub_one();
is $r1, 'one', 'Original test module return value';

dies_ok { register_mocks(bad_model => {}); } "register mocks bad model";

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

done_testing();

