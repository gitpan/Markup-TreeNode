package Markup::TreeNode;
$VERSION = '1.0.0';

use strict;

require Exporter;
require Carp;

our @ISA = qw(Exporter);
our $empty = '(empty)';

sub new {
	my $invocant = shift();
	my $class = ref($invocant) || $invocant;
	$class = bless {
		element_type	=> 'tag',
		tagname		=> '',
		attr		=> { },
		level		=> 0,
		parent		=> $empty,
		child_num	=> 0,
		children	=> [ ],
		text		=> ''
	}, 'Markup::TreeNode';
	$class->init (@_);
	return $class;
}

sub init {
	my $self = shift();
	my %args = @_;

	foreach (keys %args) {
		# enforce integrity
		if ($_ eq 'parent' && $args{$_} ne $empty) {
			$self->attach_parent($args{$_});
			next;
		}

		# enforce integrity
		if ($_ eq 'children') {
			$self->attach_children($args{$_});
			next;
		}

		if (exists $self->{$_}) {
			$self->{$_} = $args{$_};
		}
		else {
			Carp::croak ("unrecognized node option $_");
		}
	}
}

sub attach_parent {
	my ($self, $parent) = @_;

	$self->{'parent'} = $parent;
	# if setting parent, add us to [bottom of] parent children
	my $child_count = scalar(@{$self->{'parent'}->{'children'} || []});
	$self->{'parent'}->{'children'}->[$child_count] = $self;
	$self->{'child_num'} = $child_count;
}

sub attach_child {
	my ($self, $child) = @_;
	my $child_count = scalar(@{ $self->{'children'} });

	$self->{'children'}->[$child_count] = $child;
	# if setting child, add us as parent of child
	$child->{'parent'} = $self;
	$child->{'child_num'} = $child_count;
}

sub attach_children {
	my ($self, $childref) = @_;

	$self->{'children'} = $childref;
	# if setting children, add us as parent of all children
	foreach (@{$self->{'parent'}->{'children'}}) {
		$_->{'parent'} = $self;
		$_->{'child_count'} = scalar(@{$_->{'parent'}->{'children'}});
	}
}

sub get_text {
	my $self = shift();

	if ($self->{'element_type'} eq '-->text') { return $self->{'text'}; }

	my $next_node = $self->next_node();

	return (($next_node->{'element_type'} eq '-->text') ? $next_node->{'text'} : undef);
}

sub next_node {
	my $self = shift();

	if (scalar(@{ $self->{'children'} })) {
		return $self->{'children'}->[0];
	}

	my $recurse = sub {
		my ($me, $myself) = @_;
		if ($myself->{'parent'} ne $empty) {
			if ($myself->{'child_num'} < (scalar(@{ $myself->{'parent'}->{'children'} }) - 1)) {
				return ($myself->{'parent'}->{'children'}->[($myself->{'child_num'} + 1)]);
			}

			return ($me->($me, $myself->{'parent'}));
		}

		return undef;
	};

	return ($recurse->($recurse, $self));
}

# still b0rked!
sub previous_node {
	my $self = shift();

	my $recurse = sub {
		my ($me, $myself) = @_;
		if ($myself->{'parent'} ne $empty) {
			if ($myself->{'child_num'} < (scalar(@{ $myself->{'parent'}->{'children'} }) - 1)) {
				return ($myself->{'parent'}->{'children'}->[($myself->{'child_num'} - 1)]);
			}

			return ($me->($me, $myself->{'parent'}));
		}

		return undef;
	};

	return ($recurse->($recurse, $self));
}

sub drop {
	my $self = shift();
	my $ret = $self->{'parent'};

	splice @{ $self->{'parent'}->{'children'} || [] }, $self->{'child_num'}, 1;

	if ($self->{'child_num'} < scalar(@{ $self->{'parent'}->{'children'} })) {
		$ret = $self->{'parent'}->{'children'}->[$self->{'child_num'}];
	}

	foreach (@{ $self->{'children'} || [] }) { $_->drop(); };
	$self->{'parent'} = undef;
	$self->{'children'} = undef;

	return ($ret);
}

1;

__END__
=head1 NAME

Markup::TreeNode - Class representing a marked-up node (element)

=head1 SYNOPSIS

    use Markup::TreeNode;
    my $new_node = Markup::TreeNode->new(tagname => 'p');

=head1 DESCRIPTION

This module exists pretty much soley for L<Markup::Tree>. I'm sure
you can find plenty of other uses for it, but that's probably the best.
Please let me know if and how you use this outside of it's purpose,
I'm very intrested :).

=head1 PROPERTIES

At object instantiation (initilization) the following properties can be set.
Addtionally, they can be read/written in a standard hash way: C<print $node->{'text'}>.

=over 4

=item element_type

The type of element in question. Valid values follow:

=over 4

=item tag

This is the default value and it represents a standard document element.

=item -->text

TreeNodes of this element type represent textual objects.

=item -->declaration

In the real-world you'll probably have one or none of these.
It is the declaration that the XML or HTML tree has provided.
Look at the C<text> property to see what the declaration was
(intact minus the <! >.

=item -->comment

This is a representation of comments in markup.

=item -->ignore

C<element_types> marked with -->ignore will be overlooked
(but not children of -->ignore (unless they also are -->ignore))
by L<Markup::Tree>'s C<foreach_node> and C<save_as> methods.

=item -->pi

Processing Instruction. The C<tagname> will be either
C<asp-style> or C<php-style> depending on wheter the
tag was started and ended with % or ?.

=back

=item tagname

For tag C<element_type>s this is the name of the element.

For -->pi C<element_type>s this is either
C<asp-style> or C<php-style> depending on wheter the
tag was started and ended with % or ?.

For all other elements it is usually the same as C<element_type>.

=item attr

A reference to an anonymous hash. This represents
the elements attributes in name => value pairs (a hash).

=item level

Internally this setting is never used. L<Markup::Tree> uses
it to represent the depth or indentation level. You may find
other uses for it. Default value is 0.

=item parent

When present, this is the reference to the parent C<Markup::TreeNode>.
If empty the value of this property is '(empty)'.

=item child_num

Internally this is used to represent which child number of our parent we are.
Again, you may find another use for it.

=item children

A reference to an anonymous array of C<Markup::TreeNodes>s.

=item text

The text of the object. Likely -->text or -->declaration will have this set.

=back

=head1 METHODS

=over 4

=item attach_parent (C<Markup::TreeNode>)

The safe way of assigning a parent. Adds the current node to the last of
the new parent's children list.

=item attach_child (C<Markup::TreeNode>)

The safe way of assigning a child. Adds proper parent links and C<child_num>s.

=item attach_children (ARRAYREF)

The safe way of assigning a children to a parent. Adds proper parent links and C<child_num>s.

=item get_text ( )

If the current object is a -->text object it simply returns its text; Otherwise
if the C<next_node> is a text, returns its text. If all fails, undef is returned.

=item next_node ( )

Returns the next C<Markup::TreeNode> in the tree or undef if at the bottom
(or if the algo screwed up).

=item previous_node ( )

Returns the previous C<Markup::TreeNode> in the tree or undef if at the top
(or if the algo screwed up - it is in this case).

=item drop ( )

Drops (deletes) the current node and all of its children. Returns the dropped node.

=back

=head1 BUGS

The C<previous_node> method is screwy X^(

Please let me know of other bugs.

=head1 SEE ALSO

L<Markup::Tree>

=head1 AUTHOR

BPrudent (Brandon Prudent)

Email: xlacklusterx@hotmail.com
