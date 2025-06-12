This code allows you to easily mock pretty much any perl code for unit tests in a simple way with a plugin architecture.

It also has mocks for DBI and LWP code, and can be extended to mock other code as needed.

Browse the tests and POD for more information.


How to use it
=============

To be able to unit test, your code must be written so that it can be mocked.

Older codebases will probably need refactoring to allow for this. Here's
a simple example:

    # original code
    package MyModule;
    sub process_user {
        my $uid = shift;

        # do something with the uid (validation etc)

        open my $fh, '<', "/home/$uid/data.txt" or die "Cannot open file: $!";
        my $data = <$fh>;
        close $fh;

        # do something with $data
    }

As it stands, this code cannot be mocked because it directly opens a file.

By refactoring this into a separate sub that can be mocked, we can make it testable:

    # refactored code
    package MyModule;
    sub _get_user_data {
        my $uid = shift;

        open my $fh, '<', "/home/$uid/data.txt" or die "Cannot open file: $!";
        my $data = <$fh>;
        close $fh;

        return $data;
    }
    sub process_user {
        my $uid = shift;

        # do something with the uid (validation etc)

        my $data = _get_user_data($uid);

        # do something with $data
    }

Now, we can mock the `_get_user_data` sub in our tests:

    use TestModule;
    use SimpleMock qw(register_mocks);

    register_mocks({
        SUBS => {
            MyModule => {
                _get_user_data => [
                    { args => [1] , return => 'mocked data for user 1' },
                    { return => 'default mocked data for all other user IDs' },
                ],
            },
        },
    });

If you are being systematic, you can set default mocks in SimpleMocks::Mocks::MyModule
for _get_user_data, reducing the number of times you need to specify the mock in
your tests.





If you are not prepared to clean up the organization of your code, you will
not be able to use this framework effectively. The more you can refactor your code
to allow for simple mocking, the easier it will be to test it.
