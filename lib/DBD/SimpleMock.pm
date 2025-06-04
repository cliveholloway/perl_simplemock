use strict;
use warnings;

use Data::Dumper;

# built out from DBD::Nullp;
{
    package DBD::SimpleMock;

    require DBI;
    require Carp;

    our @EXPORT = qw(); # Do NOT @EXPORT anything.
    our $VERSION = "0.01";

    our $drh = undef;    # holds driver handle once initialised

    sub driver  {
        return $drh if $drh;
        my($class, $attr) = @_;
        $class .= "::dr";
        ($drh) = DBI::_new_drh($class, {
            'Name' => 'SimpleMock',
            'Version' => $VERSION,
            'Attribution' => 'Mock DBD for tests',
        });
        $drh;
    }

    sub CLONE {
        undef $drh;
    }
}


{   package DBD::SimpleMock::dr;
    our $imp_data_size = 0;
    use strict;

    sub connect { 
        my $dbh = shift->SUPER::connect(@_)
            or return;
        $dbh->STORE(Active => 1);
        return $dbh;
    }

    sub DESTROY { undef }
}


{   package DBD::SimpleMock::db;
    our $imp_data_size = 0;
    use strict;
    use Carp qw(croak);

    # Added get_info to support tests in 10examp.t
    sub get_info {
        my ($dbh, $type) = @_;

        if ($type == 29) {
            return '"';
        }
        return;
    }

    sub prepare {
        my ($dbh, $statement)= @_;

        my ($outer) = DBI::_new_sth($dbh, {
            'Statement' => $statement,
        });

        return $outer;
    }

    sub FETCH {
        my ($dbh, $attrib) = @_;
        return $dbh->SUPER::FETCH($attrib);
    }

    sub STORE {
        my ($dbh, $attrib, $value) = @_;
        if ($attrib eq 'AutoCommit') {
            Carp::croak("Can't disable AutoCommit") unless $value;
            # convert AutoCommit values to magic ones to let DBI
            # know that the driver has 'handled' the AutoCommit attribute
            $value = ($value) ? -901 : -900;
        }
        return $dbh->SUPER::STORE($attrib, $value);
    }

    sub ping { 1 }

    sub disconnect {
        shift->STORE(Active => 0);
    }

}


{   package DBD::SimpleMock::st; # ====== STATEMENT ======
    our $imp_data_size = 0;
    use strict;

    sub bind_param {
        my ($sth, $param, $value, $attr) = @_;
        $sth->{ParamValues}{$param} = $value;
        $sth->{ParamAttr}{$param}   = $attr
            if defined $attr; # attr is sticky if not explicitly set
        return 1;
    }

    sub execute {
        my ($sth, @arg) = @_;
        my $mock = SimpleMock::Model::DBI::_get_mock_for($sth->{Statement}, \@arg);
        my $field_count = @{$mock->{data}->[0]};
        $sth->STORE(NUM_OF_FIELDS => $field_count);
        $sth->STORE(Active => 1);
        $sth->{simplemock_data} = $mock->{data};
        $sth->{NAME} = $mock->{cols} if ($mock->{cols});
        1;
    }

    sub fetchrow_arrayref {
        my $sth = shift;
         
        my $data = shift @{$sth->{simplemock_data}};
        if (!$data || !@$data) {
            $sth->finish;     # no more data so finish
            return undef;
        }
        return $sth->_set_fbav($data);
    }

    *fetch = \&fetchrow_arrayref;

    sub FETCH {
        my ($sth, $attrib) = @_;
        return $sth->SUPER::FETCH($attrib);
    }

    sub STORE {
        my ($sth, $attrib, $value) = @_;
        return $sth->SUPER::STORE($attrib, $value);
    }

}

1;
