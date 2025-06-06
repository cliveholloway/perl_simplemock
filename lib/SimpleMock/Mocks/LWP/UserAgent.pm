package SimpleMock::Mocks::LWP::UserAgent;
use strict;
use warnings;

# adds a handler to LWP::UserAgent to mock HTTP requests

require LWP::UserAgent;
    
no warnings 'redefine';
my $orig = \&LWP::UserAgent::new;

*LWP::UserAgent::new = sub {
    my ($class, @args) = @_;
    my $ua = $orig->($class, @args);

    # This remains in the model to avoid circular deps
    require SimpleMock::Model::LWP;
    $ua->add_handler(request_send => \&SimpleMock::Model::LWP::mock_send_request);

    return $ua;
};

1;
