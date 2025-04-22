package SimpleMock::Model::SUBS;
use strict;
use warnings;
use SimpleMock::Util qw(
  generate_args_sha
);
use Data::Dumper;

our $SUBS;
sub register_mocks {
  my $mocks_data = shift;

  NAMESPACE: foreach my $ns (keys %$mocks_data) {
    # the module should already be loaded, but doesn't have to be
    eval { require $ns; }; $@ and die "Cannot load $ns - $@";
    SUB: foreach my $sub (keys %{$mocks_data->{$ns}}) {
      SUBCALL: foreach my $subcall (@{ $mocks_data->{$ns}->{$sub}}) {
        my $sha = generate_args_sha($subcall->{args});
        my $returns = $subcall->{returns};
        $SUBS->{$ns}->{$sub}->{$sha} = $returns;
      }

      # alias the subroutine to the mock service
      my $sub_full_name = $ns . '::' . $sub;
      no strict 'refs';
      *{$sub_full_name} = sub { _get_return_value_for_args($ns, $sub, \@_) };
    }
  }
}

sub _get_return_value_for_args {
  my ($ns, $sub, $args) = @_;
  my $sha = generate_args_sha($args);

  # if the sha is not found, use default value,
  # if no default value is found, die since a mock must be defined
  my $returns = exists $SUBS->{$ns}->{$sub}->{$sha}
                ? $SUBS->{$ns}->{$sub}->{$sha}  
                : exists $SUBS->{$ns}->{$sub}->{'_default'}
                  ? $SUBS->{$ns}->{$sub}->{'_default'}
                  : die "No mock found for $ns::$sub with args: " . Dumper($args);

  # if the return value is a code reference, call it with the args
  # else return literal value
  return ref($returns) eq 'CODE'
         ? $returns->(@$args)
         : $returns;
  }
}

1;
