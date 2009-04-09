package Catalyst::Controller::ActionRole;
# ABSTRACT: Apply roles to action instances

use Moose;
use Class::MOP;
use Catalyst::Utils;
use Moose::Meta::Class;
use String::RewritePrefix;
use MooseX::Types::Moose qw/ArrayRef Str RoleName/;
use List::Util qw(first);

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
the role name will be searched for in C<@INC> according to the rules for
L<role prefix searching|/ROLE PREFIX SEARCHING>.

Additionally it's possible to to apply roles to B<all> actions of a controller
without specifying the C<Does> keyword in every action definition:

    package MyApp::Controller::Bar

    use parent qw/Catalyst::Controller::ActionRole/;

    __PACKAGE__->config(
        action_roles => ['Foo', '~Bar'],
    );

    # has Catalyst::Action::Role::Foo and MyApp::Action::Role::Bar applied
    # if MyApp::Action::Role::Foo exists and is loadable, it will take
    # precedence over Catalyst::Action::Role::Foo
    sub moo : Local { ... }

=head1 ROLE PREFIX SEARCHING

Roles specified with no prefix are looked up under a set of role prefixes.  The
first prefix is always C<MyApp::Action::Role::> (with C<MyApp> replaced as
appropriate for your application); the following prefixes are taken from the
C<_action_role_prefix> attribute.

=attr _action_role_prefix

This class attribute stores an array reference of role prefixes to search for
role names in if they aren't prefixed with C<+> or C<~>. It defaults to
C<[ 'Catalyst::Action::Role::' ]>.  See L</role prefix searching>.

=cut

__PACKAGE__->mk_classdata(qw/_action_role_prefix/);
__PACKAGE__->_action_role_prefix([ 'Catalyst::ActionRole::' ]);

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

    my @prefixes = (qq{${app}::ActionRole::}, @{$self->_action_role_prefix});

    return String::RewritePrefix->rewrite(
        { ''  => sub {
            my $loaded = Class::MOP::load_first_existing_class(
                map { "$_$_[0]" } @prefixes
            );
            return first { $loaded =~ /^$_/ }
              sort { length $b <=> length $a } @prefixes;
          },
          '~' => $prefixes[0],
          '+' => '' },
        @shortnames,
    );
}

sub _parse_Does_attr {
    my ($self, $app, $name, $value) = @_;
    return Does => $self->_expand_role_shortname($value);
}

1;
