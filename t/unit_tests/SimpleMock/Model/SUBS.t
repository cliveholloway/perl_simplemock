use strict;
use warnings;
use Test::Most;
use SimpleMock;

use SimpleMock::Model::SUBS;

SimpleMock::Model::SUBS::register_mocks({
  'TestModule' => {

    # demo each static return type
    'sub_three' => [
      { returns => 'default mocked value' },
      { args => ['scalar'],
        returns => 'scalar' },
      { args => ['hashref'],
        returns => { key => 'value' } },
      { args => ['arrayref'],
        returns => [ 'value1', 'value2' ] },
      { args => ['array'],
        returns => sub { (1,2,3) } },
      { args => ['hash'],
        returns => sub { (key => 'value') } },
    ],

    # demo a coderef mock that uses the args sent
    'sub_four' => [
      { returns => sub { my ($arg) = @_; return $arg * 2 } },
    ],

    # wantarray example
    'sub_six' => [
      { returns => sub {
          my ($arg) = @_;
          return wantarray ? ($arg, $arg * 2) : $arg * 2;
        } },
    ],
  }
});

is TestModule::sub_three(), 'default mocked value', 'default mock';
is TestModule::sub_three('scalar'), 'scalar', 'scalar mock';
is_deeply TestModule::sub_three('hashref'), { key => 'value' }, 'hashref mock';
is_deeply TestModule::sub_three('arrayref'), [ 'value1', 'value2' ], 'arrayref mock';
my @array = TestModule::sub_three('array');
is_deeply \@array, [ 1, 2, 3 ], 'array mock';
my %hash = TestModule::sub_three('hash');
is_deeply \%hash, { key => 'value' }, 'hash mock';

is TestModule::sub_four(5), 10, 'coderef mock';
is TestModule::sub_four(10), 20, 'coderef mock with different arg';

is TestModule::sub_five(), "mocked sub_five", 'mocked sub_five in SimpleMocks::Mocks::TestModule';
is TestModule::sub_five(1,2), "mocked sub_five with args", 'mocked sub_five in SimpleMocks::Mocks::TestModule with args';

my @s6 = TestModule::sub_six(5);
is_deeply \@s6, [5, 10], 'wantarray mock array';
my $s6 = TestModule::sub_six(5);
is $s6, 10, 'wantarray mock scalar';

done_testing();
