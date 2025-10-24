package SimpleMock::Model::SUBS;
use strict;
use warnings;
use SimpleMock::Util qw(
    generate_args_sha
    file_from_namespace
);
use Data::Dumper;

our $VERSION = '0.01';

our $SUBS;
sub validate_mocks {
    my $mocks_data = shift;

    my $new_mocks = {};

    NAMESPACE: foreach my $ns (keys %$mocks_data) {

        # the module should already be loaded, but doesn't have to be
        eval {
            my $file = file_from_namespace($ns);
            require $file; 
        };
        $@ and die "Cannot load $ns - $@";

        SUB: foreach my $sub (keys %{$mocks_data->{$ns}}) {
            SUBCALL: foreach my $subcall (@{ $mocks_data->{$ns}->{$sub}}) {
                my $sha = generate_args_sha($subcall->{args});
                my $returns = $subcall->{returns};
                $new_mocks->{SUBS}->{$ns}->{$sub}->{$sha} = $returns;
            }

            # alias the subroutine to the mock service
            my $sub_full_name = $ns . '::' . $sub;
            no strict 'refs'; ## no critic
            no warnings 'redefine';
            *{$sub_full_name} = sub { _get_return_value_for_args($ns, $sub, \@_) };
        }
    }
    return $new_mocks;
}

sub _get_return_value_for_args {
    my ($ns, $sub, $args) = @_;
    my $sha = generate_args_sha($args);

    # if the sha is not found, use default value,
    # if no default value is found, die since a mock must be defined
    my $returns = exists $SimpleMock::MOCKS->{SUBS}->{$ns}->{$sub}->{$sha}
                  ? $SimpleMock::MOCKS->{SUBS}->{$ns}->{$sub}->{$sha}  
                  : exists $SimpleMock::MOCKS->{SUBS}->{$ns}->{$sub}->{'_default'}
                    ? $SimpleMock::MOCKS->{SUBS}->{$ns}->{$sub}->{'_default'}
                    : die "No mock found for $ns::$sub with args: " . Dumper($args);

    # if the return value is a code reference, call it with the args
    # else return literal value
    return ref($returns) eq 'CODE'
           ? $returns->(@$args)
           : $returns;
}

1;

=head1 NAME

SimpleMock::Model::SUBS - A module to register and handle mock subroutines.

=head1 DESCRIPTION

Allows you to override subroutines in a namespace with mock implementations. By
using this along with reasonable design patterns, you can unit test your code
in a very simple way.

=head1 USAGE

You probably won't want to use this module directly, but rather use the SimpleMock
module in your tests instead:

    use SimpleMock qw(register_mocks);

    use My Module;

    register_mocks({
        SUBS => {
            'My::Module' => {
                'my_sub' => [

                    # return a specific value for these args
                    { args => [1, 2],
                      returns => 'return value for args 1,2' },

                    # run the code reference for these args
                    # (in this example I'm not using the args, but am showing how
                    # you would access them in the sub if needed)
                    { args => [3, 4],
                      # just return a random number from 1 to 10
                      returns => sub { my ($arg1, $arg2) = @_; return int(rand(10))+1; } },

                    # return value for any other args
                    { returns => 'returns for all other args'; } },
                ],
            },
        },
    });

The structure of the subs mock call is as follows:

    register_mocks({
        SUBS => {
            'Namespace' => {
                'sub_name' => [

                    # for specific args, returns a specific value
                    { args => [$arg1, $arg2], returns => 'return value for these args' },

                    # for specific args, run the code reference with the supplied args
                    { args => [$arg1, $arg2], returns => sub { my ($arg1, $arg2) = @_; ... } },

                    # if args are omitted, the return value is used as a catchall
                    { returns => 'default return value for all other args' },
                ],
            },
        },
    });

If the catchall is omitted, the sub call will die if the args sent do not match
any of the defined mocks.

The return value can be a literal value, or a code reference. If it is a code
reference, it will be called with the args passed to the subroutine. This is
useful for generating dynamic return values based on the input arguments. The subref
should generally be used as a catchall, but there are cases where you might want to
use it for specific args (eg for a random response).

Use the coderef approach too if you need to return a hash or array, or if
you need to support wantarray calls. I originally considered doing this via another
key in the mock definition, but it seemed simpler to just use a coderef for these.

=cut
