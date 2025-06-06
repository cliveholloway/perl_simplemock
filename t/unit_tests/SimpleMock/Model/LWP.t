use strict;
use warnings;
use Test::Most;
use SimpleMock;

use SimpleMock::Model::LWP;

use LWP::UserAgent;

my $ua = LWP::UserAgent->new;

SimpleMock::Model::LWP::register_mocks({

    'http://example.com' => {

        'GET' => [
            # static request with simple response
            { response => 'Response for GET request with no args' },

            # request with args and simple response
            { args     => { foo => 'bar' },
              response => 'Response for GET request with args',
            },

            # request with args and bespoke response
            { args => { foo2 => 'bar2' },
              response => {
                  code => 404,
                  message => "Can't find it, dammit!",
                  headers => {
                      'x-response-test' => 'foo',
                  }
              }
            },
        ],

        'POST' => [
            { args     => { foo3 => 'bar3' },
              response => 'Response for POST request with args',
            }
        ],

    },

});

my $r1 = $ua->get('http://example.com');
isa_ok($r1, 'HTTP::Response', 'HTTP::Response object created');
is $r1->content, 'Response for GET request with no args', 'GET request with no args';

my $r2 = $ua->get('http://example.com?foo=bar');
is $r2->content, 'Response for GET request with args', 'GET request with QS args';

my $r3 = $ua->get('http://example.com?foo2=bar2');
is $r3->content, '', "Bespoke response - content";
is $r3->code, 404, "Bespoke response - code";
is $r3->message, "Can't find it, dammit!", "Bespoke response - message";
my $header = $r3->header('x-response-test');
is $header, 'foo', "Bespoke response - header";

my $r4 = $ua->post('http://example.com', {
            foo3 => 'bar3'
         });
is $r4->content, 'Response for POST request with args', "POST request with args";

done_testing();
