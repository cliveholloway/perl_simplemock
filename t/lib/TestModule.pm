package TestModule;
use strict;
use warnings;

# constants are subs, so we need to not mock them (at least for now)
use constant 'TEST_CONSTANT', 42;

# sub_one is not mocked, while sub_two is in SimpleMock::Mocks::TestModule
# (just for the test)
sub sub_one { 'one'; }
sub sub_two { 'two'; }

# used in test for SimpleMock::Model::SUBS
sub sub_three { 'three'; }
sub sub_four { 'four'; }
sub sub_five { 'five'; }
sub sub_six { 'six'; }

1;
