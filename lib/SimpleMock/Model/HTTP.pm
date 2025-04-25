package SimpleMock::Model::HTTP;
use strict;
use warnings;
use HTTP::Status qw(status_message);
use URI::QueryParam;
use URI;
use Data::Dumper;

use SimpleMock::Util qw(
  generate_args_sha
);

our $HTTP;

BEGIN {
  use LWP::UserAgent;
  no warnings 'redefine';
  my $orig = \&LWP::UserAgent::new;
  *LWP::UserAgent::new = sub {
    my ($class, @args) = @_;
    my $ua = $orig->($class, @args);
    $ua->add_handler(
      request_send => \&mock_send_request,
    );
    return $ua;
  };
}

sub mock_send_request {
  my ($request, $ua, $h) = @_;
  my $method = $request->method;
  my $url = $request->uri;

  # initially, only supporting 'application/x-www-form-urlencoded'
  my %request_args;
  if ($method eq 'POST') {
    my $content = $request->content;
    my $uri = URI->new("http:dummy/");  # dummy base to reuse parser
    $uri->query($content);
    %request_args = $uri->query_form;
  }
  elsif ($method eq 'GET') {
    my $uri = URI->new($request->uri);
    %request_args = $uri->query_form;
  }

  my $args_sha = generate_args_sha(\%request_args);

  # remove QS from URL before lookup
  $url =~ s/\?.*//;
  my $response = $HTTP->{$url}->{$method}->{$args_sha}
                  or die "No mock is defined for url ($url), method ($method), args: ". Dumper(\%request_args);
  
  return $response;
}

sub register_mocks {
  my $mocks_data = shift;

  URL: foreach my $url (keys %$mocks_data) {
    METHOD: foreach my $method (keys %{$mocks_data->{$url}}) {
      MOCK: foreach my $mock (@{ $mocks_data->{$url}->{$method}}) {
        my $response_arg_or_content = $mock->{response};
        my $response_arg = ref $response_arg_or_content eq 'HASH'
                           ? $response_arg_or_content
                           : { content => $response_arg_or_content };

        $response_arg->{code}    //= 200;
        $response_arg->{message} //= status_message($response_arg->{code});
        $response_arg->{content} //= '';
        $response_arg->{headers} //= {};

        my $response = HTTP::Response->new(
                         $response_arg->{code},
                         $response_arg->{message},
                         HTTP::Headers->new( %{ $response_arg->{headers} } ),
                         $response_arg->{content},
                       );

        my $sha = generate_args_sha($mock->{args});   
        $HTTP->{$url}->{$method}->{$sha} = $response;
      }
    }
  }
}

1;
