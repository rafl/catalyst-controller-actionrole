package Catalyst::Action::TestActionClass;
use parent 'Catalyst::Action';

sub execute {
    my ( $self, $controller, $c ) = @_;
    $c->response->body(__PACKAGE__);
};

1;
