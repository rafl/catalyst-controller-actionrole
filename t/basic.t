use strict;
use warnings;
use Test::More tests => 12;

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

my %roles = (
    foo  => 'TestApp::ActionRole::Moo',
    bar  => 'TestApp::ActionRole::Moo',
    baz  => 'Moo',
    quux => 'Catalyst::ActionRole::Zoo',
);

while (my ($path, $role) = each %roles) {
    my $resp = request("/foo/${path}");
    ok($resp->is_success);
    is($resp->content, $role);
    is($resp->header('X-Affe'), 'Tiger');
}
