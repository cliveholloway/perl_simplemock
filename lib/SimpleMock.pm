package SimpleMock;
use strict;
use warnings;
use Exporter 'import';
use File::Basename qw(dirname);
use Cwd 'abs_path';
use Hash::Merge qw(merge);
use Carp qw(carp);

use SimpleMock::Util qw(
    all_file_subs
    generate_args_sha
    namespace_from_file
);

our @EXPORT_OK = qw(
    register_mocks
);

our $VERSION = '0.01';

# all mocks get set in this namespace to make managing them easier
our $MOCKS = {};

# enable this env var to troubleshoot
sub _debug {
    my $message = shift;
    $ENV{DEBUG_SIMPLEMOCK} and carp "DEBUG: $message";
}

sub register_mocks {
    my %mocks_data = @_;

    foreach my $model (keys %mocks_data) {
        $model =~ /^[A-Z_]+$/ or die "Mock model class must be ALL_CAPS and underscores only! ($model)";
        my $model_ns = 'SimpleMock::Model::'.$model;
        # should already be loaded, but we do this to catch any bad model names
        eval "require $model_ns"; $@ and die $@; ## no critic
        my $validated_mocks = $model_ns.'::validate_mocks';
        no strict 'refs'; ## no critic
        $MOCKS = merge($MOCKS, $validated_mocks->($mocks_data{$model}));
    }
}

sub _load_mocks_for {
    my $original_filename = shift;
     _debug("_load_mocks_for($original_filename)");
    # Skip if the file is a SimpleMock file
    return if $original_filename =~ /^SimpleMock/;

    my $mock_filename = "SimpleMock/Mocks/$original_filename";
    eval {
        require $mock_filename;
    };
    if ($@) {
        # mock doesn't exist
        $@ =~ /Can't locate/ and return;
        # mock is borked
        die "Error loading $mock_filename: $@";
    }
    _debug("Loaded mocks for $original_filename ($mock_filename)");

    # map any method that exists in the mock over to the original
    # as a default mock
    my @module_subs = all_file_subs($original_filename);
    my $mock_ns = namespace_from_file($mock_filename);
    my $original_ns = namespace_from_file($original_filename);

    my $default_sub_mocks;
    foreach my $sub_name (@module_subs) {
        $sub_name =~ s/.*:://;
        my $mock_sub = $mock_ns.'::'.$sub_name;
        no strict 'refs'; ## no critic
        if (defined &{$mock_sub}) {
            _debug("Mapping mock sub $mock_sub to original sub ${original_ns}::$sub_name");
            $default_sub_mocks->{$original_ns}->{$sub_name} = [ { returns => \&{$mock_sub} } ];
        }
    }
    register_mocks(
        SUBS => $default_sub_mocks
    );
}

# override "require" to trigger loading of mocks
BEGIN {
    our %processed;
    *CORE::GLOBAL::require = sub {
        my $filename = shift;

        # special cases (not module loads)
        return CORE::require($filename)
            if ($filename !~ /[A-Za-z]/ || $filename =~ /\.pl$/);

        # if namespace, switch to file name
        unless ($filename =~ /\.pm$/) {
            $filename =~ s|::|/|g;
            $filename .= '.pm';
        }

        # only load if not already processed
        unless ($processed{$filename}) {
            $processed{$filename}=1;
            eval { CORE::require($filename) };
            $@ and _debug("Can't require file $filename: $@");
            _load_mocks_for($filename);
        }
    };
}

1;

=head1 NAME

SimpleMock - A simple mocking framework for Perl

=head1 SYNOPSIS

    use SimpleMock qw(register_mocks);

    # register mocks for a model
    register_mocks(
        SUBS => {
            'MyModule' => {
                'my_method' => [
                    { returns => sub { return 42 } },
                ],
            },
        },
        DBI => {
            QUERIES => [
                ...
            ],
        },
        LWP => {
            ...
        },
    );

=head1 DESCRIPTION

SimpleMock is a simple mocking framework for Perl. It allows you to
easily mock various integrations in your code via mocks. Initially, the
following models are supported:

=over

=item * SUBS - for mocking subroutine calls
=item * DBI - for mocking DBI code
=item * LWP - for mocking LWP::UserAgent code

See documentation in each SimpleMock::Model::* namespace for details of 
the mock data formats.

=back

Other models can easily be added via the SimpleMock::Model namespace.

Currently, there is no versioning of the mocks, so you should
ensure that the mocks you use are compatible with the version of the
module you are mocking. If there is a good reason to version the mocks,
I have architected it, but not implemented. Please contact me with
requirements if you need this feature.

=head2 SUBS

Easily override subs in your code for testing purposes. It works by
overriding the "require" function to load mock files when a module
is loaded to load mock methods on top of the original methods. This allows
you to create mock methods that can be used in your tests without
modifying the original code. The mock methods can be defined in three ways:

=head3 In a default mock module

Any method in SimpleMock::Mocks::Namespace that matches a method in the original
Namespace module will be used as a default mock. This distribution comes with
a mock for TestModule.pm that overrides a couple of methods.

Please consider contributing common SimpleMock::Mocks::* mocks for cpan
modules to add to the distribution via a pull request on GitHub.

=head3 Via calls to register_mocks in the mocks modules

Calls to register_mocks in individual SimpleMock::Mocks modules allow you to
set mocks that are available to all tests. This is useful for setting up a
default mock for a module that is used in many tests.

=head3 Via calls to register_mocks in your test code

You can extend the existing mocks (and override default mocks) by calling
register_mocks in your test code. This allows you to create mocks that are
fine tuned to your test cases.

=head1 METHODS

=head2 register_mocks

This is the only public method in the module. It takes a hash of model mocks
where the top level keys refer to the model namespace under SimpleMock::Model
and the values define the actual mocks. Different mocks can have different
formats - eg, SUBS have namespaces with methods, DBI has a different format.

    use SimpleMock qw(register_mocks);

    register_mocks(
        SUBS => {
            'MyModel' => {
                'my_method' => [
                    { returns => sub { return 42 } },
                ],
            },
        },
        DBI => {
            QUERIES => [
                {
                    sql => 'SELECT name, email FROM user where name like=?',
                    results => [
                        # data is an arrayref of arrayrefs of results
                        { args => [ 'C%' ], data => $d1 },
                        # if you set a result with no args, it will be used as the default
                        { data => $d2 },
                    ],
                },
                {
                    sql => 'SELECT id, name, email FROM member WHERE name like=?',
                    # cols is only needed if using selectall_hashref etc
                    cols => [ 'id', 'name', 'email' ],
                    results => [
                        { args => [ 'C%' ], data => $d3 },
                        { args => [ 'D%' ], data => $d4 },
                    ],
                },
            ],
        },
    );

See the documentation in each SimpleMock::Model::* namespace for details of mock
data formats.

=head1 AUTHOR

Clive Holloway <clive.holloway@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2025 by Clive Holloway.
This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

