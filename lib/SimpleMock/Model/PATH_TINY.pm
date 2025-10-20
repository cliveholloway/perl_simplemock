package SimpleMock::Model::PATH_TINY;
use strict;
use warnings;
use Path::Tiny;

use Data::Dumper;

our $VERSION = '0.01';

our %PATH_TINY_MOCKS = ();

# list attributes that can be 0 (false) or 1 (true)
our @t_f_keys = qw(assert exists has_same_bytes);
my %t_f = (0 =>1, 1=>1);

sub register_mocks {
    my $mocks_data = shift;

    PATH: foreach my $path (keys %$mocks_data) {
        # implicit directory if has children
        $mocks_data->{$path}->{is_dir} =1 if $mocks_data->{$path}->{children};

        T_F_KEY: foreach my $key (@t_f_keys) {
            my $val = $mocks_data->{$path}->{$key};
            next T_F_KEY unless defined $val;
            $t_f{$val} or die "Invalid value for key '$key' in Path::Tiny mock for path '$path' - must be 0|1"; 
        }

        $PATH_TINY_MOCKS{$path} = $mocks_data->{$path};
    }
}


1;

