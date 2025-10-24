use strict;
use warnings;
use Test::Most;
use SimpleMock qw(register_mocks);

use Data::Dumper;

use SimpleMock::Model::PATH_TINY;

my $sample_data = <<'_END_';
This is a test file
spread over
multiple lines
_END_

SimpleMock::register_mocks(
    PATH_TINY => {
        '/my/test/absolute/path/file.txt' => {

            # needed for file read calls
            data => $sample_data,
    
            # by default, assert is true, but you can override on a per mock
            # (but not per assertion). If this is problematic it can be refactored later
            assert=> 0,
    
            # digest method is hard coded to whatever this value is
            digest => '1a2b3c4d5e6f',
    
            # set the 'exists' flag - defaults to true if not set
            exists => 0,
    
            # set the has_same_bytes flag (for all files - not mocked the functionality intyernally)
            has_same_bytes => 1,
    
            # return value for ->stat call (must be an arrayref and match 'stat' command return val
            # (ie this is bad but valid for the test)
            # ->lstat returns the same value
            stat => [1,2,3,4],
        },
        '/my/test/absolute/path/file2.txt' => {
            data => $sample_data,
        },
        # children are calculated from a regex on the file paths
        '/my/test/dir' => {},
        # empty mocks so that 'children' doesn't fail with 'No mock defined for path' 
        # of course, you may not want to define these if you want the children call to throw
        # note: must mark directories with the is_dir flag
        '/my/test/dir/dir1' => {},
        '/my/test/dir/dir2' => {},
        '/my/test/dir/file1.txt' => {},
        # not a child
        '/my/test/dir/dir2/dir3' => {},
        
        # copy file to this dir
        '/copied' => {},
    
        # realpath test
        '/hello/dog/../there' => {},
    },
);
    
use Path::Tiny;

eval { use Unicode::UTF8; };
my $no_utf8 = $@;

eval { path('/this/path/is/not/mocked'); };
like $@, qr/^No mock defined for path/, "Unmocked path throws exception";

my $p1 = path('/my/test/absolute/path/file.txt');
isa_ok($p1, 'Path::Tiny');
is $p1->[0], '/my/test/absolute/path/file.txt', "Correct path";

my $t1 = $p1->slurp;
is $t1, $sample_data, "Sample data slurped";

# these are both synonyms for slurp right now. Will decide if they need separate methods later
my $t2 = $p1->slurp_raw;
is $t2, $sample_data, "Sample data slurped raw";
my $t3 = $p1->slurp_utf8;
is $t3, $sample_data, "Sample data slurped utf8";

my $s1 = $p1->spew;
is_deeply $s1, $p1, "spew no ops ands returns self";

my $s2 = $p1->spew_raw;
is_deeply $s2, $p1, "spew_raw no ops and returns self";

SKIP: {
    skip "Missing Unicode::UTF8", 1 if $no_utf8;
    my $s2 = $p1->spew_utf8;
    is_deeply $s2, $p1, "spew_utf8 no ops and returns self";
};

is $p1->chmod('0644'), 1, "chmod no-op";

{
    local $ENV{PATH_TINY_CWD} = '/my/cwd';
    my $cwd = Path::Tiny->cwd;
    isa_ok $cwd, 'Path::Tiny';
    is $cwd->[0], '/my/cwd', 'cwd obj retrieved successfully';
}
eval { $p1->assert(sub { 'Any code here (ignored in mocks)' }) };
like $@, qr/failed assertion/, "explicit asset=0 throws exception";

my $p2 = path('/my/test/absolute/path/file2.txt');
is_deeply $p2->assert(sub { 'Any code here (ignored in mocks)' }), $p2, "asserts are true by default";

eval { $p2->cached_temp };
like $@, qr/has no cached File::Temp object/, "Error or no cached temp file";

eval { $p1->assert(sub { 'whatever' }) };
like $@, qr/Error assert on/, "Assert fails";

is_deeply $p2, $p2->assert(sub { 'whatever' }), 'assert()';

my $p3 = path('/my/test/dir');
my @p3_children = $p3->children;

my @expected = sort (path('/my/test/dir/dir1'), path('/my/test/dir/dir2'), path('/my/test/dir/file1.txt'));
is_deeply \@p3_children, \@expected, "children()";

# throws exception when parent isn't a directory
throws_ok sub { $p2->children }, qr/Error opendir on/, "files can't have children()";

# copy a file to a full name
is $SimpleMock::MOCKS->{PATH_TINY}->{'/copied/file.txt'}, undef, "copied mock doesn't exist yet";
my $p4 = $p1->copy('/copied/new_file.txt');
ok $SimpleMock::MOCKS->{PATH_TINY}->{'/copied/new_file.txt'}, "New mock created with full path";
is_deeply $SimpleMock::MOCKS->{PATH_TINY}->{'/copied/new_file.txt'},
          $SimpleMock::MOCKS->{PATH_TINY}->{'/my/test/absolute/path/file.txt'},
          'copy() copied the mock to a file name';

# copy to a directory
is $SimpleMock::MOCKS->{PATH_TINY}->{'/copied/file2.txt'}, undef, "copied mock doesn't exist yet";
my $p5 = $p2->copy('/copied');
ok $SimpleMock::MOCKS->{PATH_TINY}->{'/copied/file2.txt'}, "New mock created in target dir";
is_deeply $SimpleMock::MOCKS->{PATH_TINY}->{'/copied/file2.txt'},
          $SimpleMock::MOCKS->{PATH_TINY}->{'/my/test/absolute/path/file2.txt'},
          'copy() copied the mock to a directory';

# digest
is $p1->digest, '1a2b3c4d5e6f', "Digest value returned";

# digest missing
throws_ok sub { $p2->digest }, qr/'digest' attribute must be defined/, "Exception thrown if digest attr not defined";

# test operators
ok $p2->is_file, "is_file for file";
ok ! $p2->is_dir, "is_dir for file";
ok ! $p3->is_file, "is_file for dir";
ok $p3->is_dir, "is_dir for dir";

# exists
ok ! $p1->exists, 'file/dir doesn\'t exist';

ok $p2->exists, 'file/dir exists';

# exists - only p1 and p2 have explicit exists value
ok $p1->has_same_bytes('some file'), 'has_same_bytes true';
ok ! $p2->has_same_bytes('some file'), 'has_same_bytes false';

my $p6 = path('/my/test/dir/dir2/dir3');
my $it1 = $p6->iterator;
is $it1->(), undef, "iterator with no entries";

my $it2 = $p3->iterator;
my $count=0;
$count++ while (my $ip = $it2->() );
is $count, 3, 'iterator count';

throws_ok sub { $p3->iterator({ recurse => 1 }); }, qr/'recurse' is not supported on iterator/, "Iterator mock doesn't support 'recurse' arg";

my @lines = $p1->lines;
is @lines, 3, "line count";
is $lines[0], "This is a test file\n", "first line";

@lines = $p1->lines({ count => 1 });
is @lines, 1, "line count (explicit count)";
is $lines[0], "This is a test file\n", "first line (explicit count)";

@lines = $p1->lines({ chomp => 1 });
is $lines[0], "This is a test file", "first line (chomped)";

my $p7 = $p1->parent;
is $p7->[0], '/my/test/absolute/path', 'parent';
$p7 = $p1->parent(2);
is $p7->[0], '/my/test/absolute', 'parent 2';

throws_ok sub { path('/hello/dog/../there')->realpath; }, qr/Not implemented/, 'realpath not implemented';

my $p8 = $p1->relative('/my/test/absolute/');
is $p8->[0], 'path/file.txt', 'relative';

# length of data attr
is $p1->size, 47, 'length()';

is ref $p1->stat, 'ARRAY', 'stat() call';
throws_ok sub { $p2->stat }, qr/stat must be defined in mock/, "No stat attr in mock throws";

is_deeply $p1->stat, $p1->lstat, 'lstat is a stat alias';



done_testing();
