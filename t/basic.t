use strict;
use warnings;
use Test::More tests => 6;

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

my %roles = (
    foo => 'Catalyst::Action::Role::Moo',
    bar => 'TestApp::Action::Role::Moo',
    baz => 'Moo',
);

while (my ($path, $role) = each %roles) {
    my $resp = request("/foo/${path}");
    ok($resp->is_success);
    is($resp->content, $role);
}
