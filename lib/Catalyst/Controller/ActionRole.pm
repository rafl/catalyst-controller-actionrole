use strict;
use warnings;

package Catalyst::Controller::ActionRole;

use Moose;
use Class::MOP;
use String::RewritePrefix;
use MooseX::Types::Moose qw/Str/;
use Moose::Util qw/find_meta/;

use namespace::clean -except => 'meta';

extends 'Catalyst::Controller';

has _action_role_prefix => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build__action_role_prefix',
);

sub _build__action_role_prefix {
    my ($self) = @_;
    my $action_class = $self->_action_class;
    return qq{${action_class}::Role::};
}

sub create_action {
    my ($self, %args) = @_;

    my $class = exists $args{attributes}->{ActionClass}
        ? $args{attributes}->{ActionClass}
        : $self->_action_class;

    Class::MOP::load_class($class);

    my @roles = @{ $args{attributes}->{Does} || [] };
    if (@roles) {
        Class::MOP::load_class($_) for @roles;
        my $meta = find_meta($class)->create_anon_class(
            superclasses => [$class],
            roles        => \@roles,
            cache        => 1,
        );
        $meta->add_method(meta => sub { $meta });
        $class = $meta->name;
    }

    return $class->new(%args);
}

sub _parse_Does_attr {
    my ($self, $app, $name, $value) = @_;
    return Does => String::RewritePrefix->rewrite(
        { ''  => $self->_action_role_prefix,
          '~' => (blessed($app) || $app) . '::Action::Role::',
          '+' => '' },
        $value,
    );
}

1;
