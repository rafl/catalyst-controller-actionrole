package TestApp::Controller::Foo;

use Moose;

BEGIN { extends 'Catalyst::Controller::ActionRole'; }

sub bar : Local MyActionRole('Moo') {}

1;
