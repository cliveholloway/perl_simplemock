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

my $d4 = [
    [ 1, 'Dave', 'dave@testme.com' ],
    [ 2, 'Diane', 'diane@testme.com' ],
];

SimpleMock::Model::DBI::register_mocks({
    QUERIES => [
        {
            sql => 'SELECT name, email FROM user WHERE name like=?',
            results => [
                { args => [ 'C%' ], data => $d1 },
                # if you set a result with no args, it will be used as the default
                { data => $d2 },
            ],
        },
        {
            sql => 'SELECT id, name, email FROM user WHERE name like=?',
            # cols is only needed if using selectall_hashref etc
            cols => [ 'id', 'name', 'email' ],
            results => [
                { args => [ 'C%' ], data => $d3 },
                { args => [ 'D%' ], data => $d4 },
            ],
        },
    ],
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
is $sth->fetchrow_arrayref, undef, "fetchrow_arrayref 3 (undefined)";

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

# selectrow_hashref
$result = $dbh->selectrow_hashref('SELECT id, name, email FROM user where name like=?', undef, 'D%');
is_deeply $result, { email => 'dave@testme.com', name => 'Dave', id => 1 }, 'selectrow_hashref';

# META field tests
dies_ok { $dbh->do('SELECT unmocked query') } 'dies on unmocked query';
# update the meta field to allow undefined queries to silently run
SimpleMock::Model::DBI::register_mocks({
  META => {
    allow_unmocked_queries => 1,
  },
});
lives_ok { $dbh->do('SELECT unmocked query') }  'doesn\'t die on unmocked query';

# make all queries fail on execution
SimpleMock::Model::DBI::register_mocks({
    META => {
        execute_fail => 1
    }
});
$sth = $dbh->prepare('SELECT name, email FROM user where name like=?');
dies_ok { $sth->execute('C%') } 'execute() fails as expected';

# have the prepare fail
SimpleMock::Model::DBI::register_mocks({
    META => {
        prepare_fail => 1,
    }
});
dies_ok { $dbh->prepare('SELECT name, email FROM user where name like=?') }
  'META prepare_fail dies on prepare';

# have the connect fail
SimpleMock::Model::DBI::register_mocks({
    META => {
        connect_fail => 1,
    }
});

dies_ok { DBI->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 }); }
  'META connect_fail w RaiseError dies';

ok ! DBI->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 0 }),
  'META connect_fail w/o RaiseError returns undef';

# die on bad META key
dies_ok {
    SimpleMock::Model::DBI::register_mocks({
        META => {
            bad_key => 1,
        }
    });
} 'dies on bad META key';

done_testing();
