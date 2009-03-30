package Catalyst::Controller::ActionRole;
# ABSTRACT: Apply roles to action instances

use Moose;
use Class::MOP;
use Catalyst::Utils;
use Moose::Meta::Class;
use String::RewritePrefix;
use MooseX::Types::Moose qw/ArrayRef Str RoleName/;

use namespace::clean -except => 'meta';

extends 'Catalyst::Controller';

=head1 SYNOPSIS

    package MyApp::Controller::Foo;

    use parent qw/Catalyst::Controller::ActionRole/;

    sub bar : Local Does('Moo') { ... }

=head1 DESCRIPTION

This module allows to apply roles to the C<Catalyst::Action>s for different
controller methods.

For that a C<Does> attribute is provided. That attribute takes an argument,
that determines the role, which is going to be applied. If that argument is
prefixed with C<+>, it is assumed to be the full name of the role. If it's
prefixed with C<~>, the name of your application followed by
C<::Action::Role::> is prepended. If it isn't prefixed with C<+> or C<~>,
the value of the C<_action_role_prefix> attribute will be prepended.

Additionally it's possible to to apply roles to B<all> actions of a controller
without specifying the C<Does> keyword in every action definition:

    package MyApp::Controller::Bar

    use parent qw/Catalyst::Controller::ActionRole/;

    __PACKAGE__->config(
        action_roles => ['Foo', '~Bar'],
    );

    sub moo : Local { ... } # has Catalyst::Action::Role::Foo and MyApp::Action::Role::Bar applied

=attr _action_role_prefix

This class attribute stores a string that is going to be prepended to all role
names if they aren't prefixed with C<+> or C<~>. It defaults to
C<Catalyst::Action::Role::>.

=cut

__PACKAGE__->mk_classdata(qw/_action_role_prefix/);
__PACKAGE__->_action_role_prefix('Catalyst::Action::Role::');

=attr _action_roles

This attribute stores an array reference of role names that will be applied to
every action of this controller. It can be set by passing a C<action_roles>
argument to the constructor. The same expansions as for C<Does> will be
performed.

=cut

has _action_role_args => (
    is         => 'ro',
    isa        => ArrayRef[Str],
    init_arg   => 'action_roles',
    auto_deref => 1,
);

has _action_roles => (
    is         => 'ro',
    isa        => ArrayRef[RoleName],
    init_arg   => undef,
    lazy_build => 1,
    auto_deref => 1,
);

sub _build__action_roles {
    my $self = shift;
    my @roles = $self->_expand_role_shortname($self->_action_role_args);
    Class::MOP::load_class($_) for @roles;
    return \@roles;
}

around new => sub {
    my $next = shift;
    my $self = $next->(@_);
    # force this to run at object creation time
    $self->_action_roles;
    return $self;
};

sub create_action {
    my ($self, %args) = @_;

    my $class = exists $args{attributes}->{ActionClass}
        ? $args{attributes}->{ActionClass}->[0]
        : $self->_action_class;

    Class::MOP::load_class($class);

    my @roles = ($self->_action_roles, @{ $args{attributes}->{Does} || [] });
    if (@roles) {
        Class::MOP::load_class($_) for @roles;
        my $meta = Moose::Meta::Class->initialize($class)->create_anon_class(
            superclasses => [$class],
            roles        => \@roles,
            cache        => 1,
        );
        $meta->add_method(meta => sub { $meta });
        $class = $meta->name;
    }

    return $class->new(\%args);
}

sub _expand_role_shortname {
    my ($self, @shortnames) = @_;
    my $app = Catalyst::Utils::class2appclass(blessed($self) || $self);

    return String::RewritePrefix->rewrite(
        { ''  => $self->_action_role_prefix,
          '~' => qq{${app}::Action::Role::},
          '+' => '' },
        @shortnames,
    );
}

sub _parse_Does_attr {
    my ($self, $app, $name, $value) = @_;
    return Does => $self->_expand_role_shortname($value);
}

1;
