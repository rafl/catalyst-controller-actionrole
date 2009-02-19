package TestApp::Action::Role::Moo;

use Moose::Role;

after execute => sub {
    my ($self, $controller, $c) = @_;
    $c->response->body('moo');
};

1;
