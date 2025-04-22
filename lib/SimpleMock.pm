package SimpleMock;
use strict;
use warnings;
use Exporter 'import';
use File::Basename qw(dirname);
use Cwd 'abs_path';
use Data::Dumper;
use Hash::Merge;
use Carp qw(carp);

use SimpleMock::Util qw(
  all_file_subs
  generate_args_sha
  namespace_from_file
);

our @EXPORT_OK = qw(
  register_mocks
);

# enable this to troubleshoot
our $DEBUG=0;

sub _debug {
  my $message = shift;
  $DEBUG and carp "DEBUG: $message";
}

sub register_mocks {
  my %mocks_data = @_;
  foreach my $model (keys %mocks_data) {
    $model =~ /^[A-Z_]+$/ or die "Mock model class must be ALL_CAPS and underscores only! ($model)";
    my $model_ns = 'SimpleMock::Model::'.$model;
    eval "require $model_ns"; $@ and die $@;
    my $reg = $model_ns.'::register_mocks';
    no strict 'refs';
    $reg->($mocks_data{$model});
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
    no strict 'refs';
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
