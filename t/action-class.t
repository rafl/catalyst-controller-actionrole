use strict;
use warnings;
use Test::More tests => 2;

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

my $resp = request( "/actionclass/one" );
ok( $resp->is_success );
is( $resp->content, 'Catalyst::Action::TestActionClass' );
