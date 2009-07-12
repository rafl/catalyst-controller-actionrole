package TestAppREST::Controller::Foo;
use Moose;
use namespace::clean -except => 'meta';

BEGIN { extends 'Catalyst::Controller::ActionRole'; }

sub foo  : Local Does('Moo') ActionClass('REST') {}

1;
