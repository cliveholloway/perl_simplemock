package SimpleMock::ScopeGuard;
use strict;
use warnings;
use Scalar::Util qw(refaddr);                                                                                                                                            
                  
sub new {
    my ($class, $layer) = @_;
    return bless { layer => $layer }, $class;
}                                                                                                                                                                        
  
sub DESTROY {                                                                                                                                                            
    my $self = shift;
    my $id = refaddr($self->{layer});
    @SimpleMock::MOCK_STACK = grep { refaddr($_) != $id } @SimpleMock::MOCK_STACK;
} 

1;

=head1 NAME

SimpleMock::ScopeGuard

=head1 DESCRIPTION

Helper module to manage scoped mocks via an object that uses DESTROY to remove scoped mocks.

=cut
