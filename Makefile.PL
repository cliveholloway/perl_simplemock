use ExtUtils::MakeMaker;
WriteMakefile(
  NAME         => 'SimpleMock',
  VERSION_FROM => 'lib/SimpleMock.pm',
  ABSTRACT     => 'Generic mocking framework for Perl modules',
  AUTHOR       => 'Clive Holloway <clive.holloway@gmail.com>',
  LICENSE      => 'perl',
  PREREQ_PM    => {
    'Test::More'         => 0,
    'LWP::UserAgent'     => 0,
    'DBI'                => 0,
    'Module::Runtime'    => 0,
    'FindBin'            => 0,
    'Cwd'                => 0,
  },
);
