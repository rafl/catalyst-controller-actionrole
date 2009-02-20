package TestApp::Controller::Foo;

use Moose;

BEGIN { extends 'Catalyst::Controller::ActionRole'; }

sub foo : Local Does('Moo') {}
sub bar : Local Does('~Moo') {}
sub baz : Local Does('+Moo') {}

1;
