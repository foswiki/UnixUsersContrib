package UnixUsersContribSuite;

use Test::Unit::TestSuite;
our @ISA = qw( Test::Unit::TestSuite );

sub name { 'UnixUsersContribSuite' }

sub include_tests { qw(UnixUsersContribTests) }

1;
