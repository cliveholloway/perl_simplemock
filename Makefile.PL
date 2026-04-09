use ExtUtils::MakeMaker;
WriteMakefile(
  NAME         => 'SimpleMock',
  VERSION_FROM => 'lib/SimpleMock.pm',
  ABSTRACT     => 'Generic mocking framework for Perl modules',
  AUTHOR       => 'Clive Holloway <clive.holloway@gmail.com>',
  LICENSE      => 'perl',
  MIN_PERL_VERSION => '5.010',
  PREREQ_PM    => {
    'Carp'             => 0,
    'Data::Dumper'     => 0,
    'Digest::SHA'      => 0,
    'Exporter'         => 0,
    'Hash::Merge'      => 0,
    'Scalar::Util'     => 0,
    'Storable'         => 0,
  },
  TEST_REQUIRES => {
    'Test::Most'       => 0,
    'DBI'              => 0,
    'LWP::UserAgent'   => 0,
    'HTTP::Status'     => 0,
    'Path::Tiny'       => 0,
    'URI'              => 0,
  },
  META_MERGE => {
    'meta-spec' => { version => 2 },
    resources   => {
      repository => {
        type => 'git',
        url  => 'https://github.com/cliveholloway/perl_simplemock.git',
        web  => 'https://github.com/cliveholloway/perl_simplemock',
      },
    },
    no_index => {
      directory => [ 't', 'cover_db' ],
    },
    prereqs => {
      runtime => {
        recommends => {
          'DBI'            => 0,
          'LWP::UserAgent' => 0,
          'HTTP::Status'   => 0,
          'Path::Tiny'     => 0,
          'URI'            => 0,
        },
      },
    },
  },
);
