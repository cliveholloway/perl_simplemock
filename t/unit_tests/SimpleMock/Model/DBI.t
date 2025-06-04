use strict;
use warnings;
use Test::Most;
use SimpleMock;

use SimpleMock::Model::DBI;

use DBI;

use Data::Dumper;

my $d1 = [
  [ 'Clive', 'Clive@testme.com' ],
  [ 'Colin', 'Colin@testme.com' ],
];

my $d2 = [
  [ 'Dave', 'dave@testme.com' ],
  [ 'Diane', 'diane@testme.com' ],
];

my $d3 = [
  [ 1, 'Clive', 'Clive@testme.com' ],
  [ 2, 'Colin', 'Colin@testme.com' ],
];

# TODO - switch structure to:
# QUERIES => [
#     query => 'SELECT name, email FROM user where name like=?',
#     cols => [ 'name', 'email' ],
#     results => [
#         { args => [ 'C%' ], data => $d1 },
#         { args => [ 'D%' ], data => $d2 },
#     ],
# ],

SimpleMock::Model::DBI::register_mocks({
  QUERIES => {

    'SELECT name, email FROM user where name like=?' => [
      {
        args => [ 'C%' ],
        data => $d1,
      },
      {
        args => [ 'D%' ],
        data => $d2,
      },
    ],
    'SELECT id, name, email FROM user where name like=?' => [
        {
            args => [ 'C%' ],
            data => $d3,
            # only needed for selectall_hashref / fetchall_hashref / fetchrow_hashref etc
            cols => [ 'id', 'name', 'email' ],
        },
    ],
  },
});

# doesn't matter what we use here, as the mock will be used
my $dbh = DBI->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
isa_ok $dbh, 'DBI::db', 'connect() returns a db obj';

my $sth = $dbh->prepare('SELECT name, email FROM user where name like=?');
isa_ok $sth, 'DBI::st', 'prepare() returns sth';

# fetchall_arrayref
my $rs = $sth->execute('C%');
ok($rs, 'execute() returns true');
is_deeply $sth->fetchall_arrayref, $d1, 'fetchall_arrayref';

# fetchrow_arrayref
$sth = $dbh->prepare('SELECT name, email FROM user where name like=?');
$rs = $sth->execute('D%');
is_deeply $sth->fetchrow_arrayref, $d2->[0], "fetchrow_arrayref 1";
is_deeply $sth->fetchrow_arrayref, $d2->[1], "fetchrow_arrayref 2";
is_deeply $sth->fetchrow_arrayref, undef,    "fetchrow_arrayref 3";

# prepare_cached / fetchrow_array
$sth = $dbh->prepare_cached('SELECT name, email FROM user where name like=?');
$sth->execute('C%');
is_deeply [$sth->fetchrow_array], $d1->[0], "fetchrow_array w prepare cached";

# selectrow_arrayref
my $result = $dbh->selectrow_arrayref('SELECT name, email FROM user where name like=?', undef, 'C%');
is_deeply $result, $d1->[0], 'selectrow_arrayref';

# selectall_arrayref
$result = $dbh->selectall_arrayref('SELECT name, email FROM user where name like=?', undef, 'C%');
is_deeply $result, $d1, 'selectall_arrayref';

# selectall_hashref
$result = $dbh->selectall_hashref('SELECT id, name, email FROM user where name like=?', 'id', undef, 'C%');
is_deeply
    $result,
    {
        '2' => {
            'name' => 'Colin',
            'email' => 'Colin@testme.com',
            'id' => 2
        },
        '1' => {
            'name' => 'Clive',
            'id' => 1,
            'email' => 'Clive@testme.com'
        }
    },
    'selectall_hashref';

# META field tests
dies_ok { $dbh->do('DROP TABLE user') }  'dies on unmocked query';
# update the meta field to allow undefined queries to silently run
SimpleMock::Model::DBI::register_mocks({
  META => {
    allow_unmocked_queries => 1,
  },
});
lives_ok { $dbh->do('DROP TABLE user') }  'doesn\'t die on unmocked query';



done_testing();
