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
C<::ActionRole::> is prepended. If it isn't prefixed with C<+> or C<~>,
the role name will be searched for in C<@INC> according to the rules for
L<role prefix searching|/ROLE PREFIX SEARCHING>.

Additionally it's possible to to apply roles to B<all> actions of a controller
without specifying the C<Does> keyword in every action definition:

    package MyApp::Controller::Bar

    use parent qw/Catalyst::Controller::ActionRole/;

    __PACKAGE__->config(
        action_roles => ['Foo', '~Bar'],
    );

    # has Catalyst::ActionRole::Foo and MyApp::ActionRole::Bar applied
    # if MyApp::ActionRole::Foo exists and is loadable, it will take
    # precedence over Catalyst::ActionRole::Foo
    sub moo : Local { ... }

=head1 ROLE PREFIX SEARCHING

Roles specified with no prefix are looked up under a set of role prefixes.  The
first prefix is always C<MyApp::ActionRole::> (with C<MyApp> replaced as
appropriate for your application); the following prefixes are taken from the
C<_action_role_prefix> attribute.

=attr _action_role_prefix

This class attribute stores an array reference of role prefixes to search for
role names in if they aren't prefixed with C<+> or C<~>. It defaults to
C<[ 'Catalyst::ActionRole::' ]>.  See L</role prefix searching>.

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
    traits     => [qw(Array)],
    isa        => ArrayRef[Str],
    init_arg   => 'action_roles',
    default    => sub { [] },
    handles    => {
        _action_role_args => 'elements',
    },
);

has _action_roles => (
    traits     => [qw(Array)],
    isa        => ArrayRef[RoleName],
    init_arg   => undef,
    lazy_build => 1,
    handles    => {
        _action_roles => 'elements',
    },
);

sub _build__action_roles {
    my $self = shift;
    my @roles = $self->_expand_role_shortname($self->_action_role_args);
    Class::MOP::load_class($_) for @roles;
    return \@roles;
}

sub BUILD {
    my $self = shift;
    # force this to run at object creation time
    $self->_action_roles;
}

around create_action => sub {
    my ($orig, $self, %args) = @_;

    return $self->$orig(%args)
        if $args{name} =~ /^_(DISPATCH|BEGIN|AUTO|ACTION|END)$/;

    my $action_class = exists $args{attributes}->{ActionClass}
        ? $args{attributes}->{ActionClass}->[0]
        : $self->_action_class;

    Class::MOP::load_class($action_class);

    my @roles = ($self->_action_roles, @{ $args{attributes}->{Does} || [] });
    if (@roles) {
        Class::MOP::load_class($_) for @roles;
        my $meta = Moose::Meta::Class->initialize($action_class)->create_anon_class(
            superclasses => [$action_class],
            roles        => \@roles,
            cache        => 1,
        );
        $meta->add_method(meta => sub { $meta });
        $action_class = $meta->name;
    }

    return $action_class->new(\%args);
};

sub _expand_role_shortname {
    my ($self, @shortnames) = @_;
    my $app = $self->_application;

    my $prefix = $self->can('_action_role_prefix') ? $self->_action_role_prefix : ['Catalyst::ActionRole::'];
    my @prefixes = (qq{${app}::ActionRole::}, @$prefix);

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

=begin Pod::Coverage

  BUILD

=end Pod::Coverage

=cut

1;
