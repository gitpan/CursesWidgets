# Curses::Widgets.pm -- Base widget class for use with the
#		Curses::Application framework
#
# (c) 2001, Arthur Corliss <corliss@digitalmages.com>
#
# $Id: Widgets.pm,v 1.99 2001/12/05 09:52:40 corliss Exp $
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#####################################################################

=head1 NAME

Curses::Widgets - Base widget class for use with the Curses::Application 
framework

=head1 MODULE VERSION

$Id: Widgets.pm,v 1.99 2001/12/05 09:52:40 corliss Exp $

=head1 SYNOPSIS

	use Curses::Widgets;

	$colpr = select_colour($fore, $back);
	$colpr = select_color($fore, $back);

	$key = scankey($mwh);

	@lines = textwrap($text, 40);

	# The following are provided for use with descendent
	# classes, or are expected to be overridden.
	$obj = Curses::Widgets->new({ KEY => 'value' });
	$obj->_conf(%conf);
	$obj->reset;

	$obj->_input($ch);
	$obj->input($string);

	$obj->execute($mwh);
	$obj->draw($mwh, 1);

	$value = $obj->getField('VALUE');
	$obj->setField(
		'FIELD1'	=> 1,
		'FIELD2'	=> 'value'
		);

=head1 REQUIREMENTS

Curses

=head1 DESCRIPTION

This module serves two purposes:  to provide a framework for creating
custom widget classes, and importing a few useful functions for 
global use.

=cut

#####################################################################
#
# Environment definitions
#
#####################################################################

package Curses::Widgets;

use strict;
use vars qw($VERSION @ISA @EXPORT);
use Curses;
use Exporter;

($VERSION) = (q$Revision: 1.99 $ =~ /(\d+(?:\.(\d+))+)/);
@ISA = qw( Exporter );
@EXPORT = qw( select_colour select_color scankey textwrap );

my %colour_pairs = ( 'white:black' => 0 );
my $colour = -1;

#####################################################################
#
# Module code follows
#
#####################################################################

=head1 EXPORTED FUNCTIONS

=head2 select_colour/select_color

	$colpr = select_colour($fore, $back);
	$colpr = select_color($fore, $back);

This function returns the number of the specified colour pair.  In
doing so, it saves quite a few steps.  First, the first time it's 
called, it tests the console for colour capability.  If found, it 
then calls the (n)curses B<start_color> function for you.

After the initial colour test, this function will safely (and quietly)
return on all subsequent calls if no colour support is found.  It returns
'0', which is hardwired to 'black:white', the default for most terminals.
If colour support is present, it allocates the colour pair using (n)curses 
B<init_pair> for you, if it hasn't been done already.

Finally, the background colour is option, but if not specified, it
defaults to 'black'.

As a final note, yes, both the British and American spellings of 
'colo(u)r' are supported.

=cut

sub select_colour {
	my ($fore, $back) = @_;
	my %colours = ( 'black' => COLOR_BLACK,		'cyan'		=> COLOR_CYAN,
					'green' => COLOR_GREEN,		'magenta'	=> COLOR_MAGENTA,
					'red'	=> COLOR_RED,		'white'		=> COLOR_WHITE,
					'yellow'=> COLOR_YELLOW,	'blue'		=> COLOR_BLUE);
	my (@pairs, $pr);

	# Take an early exit unless the terminal supports colour
	return 0 if $colour == 0;

	# Check for colour support if $colours is -1
	# This is a one time check
	if ($colour == -1) {
		if (has_colors) {
			$colour = 1;
			start_color;
		} else {
			$colour = 0;
			return 0;
		}
	}

	# Make sure the foreground was specified at a minimum.
	if (! defined $fore) {
		warn "No foreground colour specified--ignoring command.\n";
		return 0;
	}

	# Set default background if necessary
	$back = "black" if (! defined $back);

	# Check to see if the colour pair has already been defined
	unless (exists $colour_pairs{"$fore:$back"}) {

		# Define a new colour pair if valid colours were passed
		if (exists $colours{$fore} && exists $colours{$back}) {
			@pairs = map { $colour_pairs{$_} } 
				keys %colour_pairs;
			$pr = 1;
			while (grep /^$pr$/, @pairs) { ++$pr };
			init_pair($pr, $colours{$fore}, $colours{$back});
			$colour_pairs{"$fore:$back"} = $pr;

		# Generate a warning if invalid colours were passed
		} else {
			warn "Invalid color pair passed:  $fore/$back--ignoring.\n";
			return undef;
		}
	}

	# Return the colour pair number
	return $colour_pairs{"$fore:$back"};
}

sub select_color {
	my @args = @_;

	return select_colour(@_);
}

=head2 scankey

	$key = scankey($mwh);

The scankey function returns the key pressed, when it does.  All
it does is loop over a (n)curses B<getch> call until something other
than -1 is returned.  Whether or not the B<getch> call is (half)-blocking
or cooked output is determined by how the (n)curses environment was
initialised by your application.  This is provided only to provide
the most basic input functionality to your application, should you decide 
not to implement your own.

The only argument is a handle to a curses/window object.

=cut

sub scankey {
	my $mwh = shift;
	my $key = -1;

	while ($key eq -1) {
		$key = $mwh->getch;
	}

	return $key;
}

=head2 textwrap

	@lines = textwrap($text, 40);

The textwrap function takes a string and splits according to the passed column
limit, splitting preferrably along whitespace.

=cut

sub textwrap {
	my $text = shift;
	my $columns = shift || 72;
	my (@tmp, @rv, $p);

	# Early exit if no text was passed
	return unless length($text);

	# Split the text into paragraphs, but preserve the terminating newline
	@tmp = split(/\n/, $text);
	foreach (@tmp) { $_ .= "\n" };
	chomp($tmp[$#tmp]) unless $text =~ /\n$/;

	# Split each paragraph into lines, according to whitespace
	for $p (@tmp) {
		while (length($p) > $columns) {
			if (substr($p, 0, $columns) =~ /^(.+\s)(\S+)$/) {
				push(@rv, $1);
				$p = $2 . substr($p, $columns);
			} else {
				push(@rv, substr($p, 0, $columns));
				substr($p, 0, $columns) = '';
			}
		}
		push(@rv, $p);
	}

	return @rv;
}


=head1 METHODS

=head2 new

	$obj = Curses::Widgets->new({ KEY => 'value' });

The new class method provides a basic constructor for all descendent
widget classes.  Internally, it assumes any configuration information to
be passed in a hash ref as the sole argument.  It dereferences that ref
and passes it to the internal method B<_conf>, which is expected to do
any input validation/initialisation required by your widget.  That method
should return a 1 or 0, which will determine if B<new> returns a handle
to the new object.

If B<_conf> returns a 1, the B<_copy> is called to back up the initial
state information.

=cut

sub new {
	my $class = shift;
	my $conf = shift;
	my $self = {};

	bless $self, $class;

	if ($self->_conf(%$conf)) {
		$self->_copy($self->{CONF}, $self->{OCONF});
		return $self;
	} else {
		return undef;
	}

}

=head2 _conf

	$self->_conf(%conf);

This method should be overridden in your descendant class.  As mentioned
above, it should do any initialisation and validation required, based on
the passed configuration hash.  It should return a 1 or 0, depending on
whether any critical errors were encountered during instantiation.

B<Note:>  your B<_conf> method should call, as a last act, 
B<$self->SUPER::_conf>.  If you don't do this, then you should include 
the following code at the end of your method:

	$self->{CONF} = { %conf };
	$self->{OCONF} = {};

As a final note, here are some rules regarding the structure of your
configuration hash.  You *must* save your state information in this hash.  
Another subroutine will copy that information after object instantiation 
in order to support the reset method.  Also note that everything stored 
in this should *not* be more than one additional level deep (in other 
words, values can be hash or array refs, but none of the values in *that* 
structure should be refs), otherwise those refs will be copied over, instead 
of the data inside the structure.  This essentially destroys your backup.

If you have special requirements, override the _copy method as well.

=cut

sub _conf {
	my $self = shift;
	my %conf = ( @_ );

	$self->{CONF} = { %conf };
	$self->{OCONF} = {};

	return 1;
}

sub _copy {
	# Synchronises the current data record with the old 
	# data record.
	# 
	# Internal use only.

	my $self = shift;
	my ($data, $odata) = @_;
	my $field;

	# Empty the target hash
	%$odata = ();

	# Copy each element to the target
	foreach $field (keys %$data) {
		if (ref($$data{$field}) eq 'ARRAY') {
			$$odata{$field} = [ @{ $$data{$field} } ];
		} elsif (ref($$data{$field}) eq 'HASH') {
			$$odata{$field} = { %{ $$data{$field} } };
		} else {
			$$odata{$field} = $$data{$field};
		}
	}
}

=head2 reset

	$obj->reset;

The reset method resets the object back to the original
state by copying the original configuration information into
the working hash.

=cut

sub reset {
	my $self = shift;

	# Reset the widget to it's original instantiated state
	$self->_copy($self->{OCONF}, $self->{CONF});
}

=head2 _input

	$self->_input($ch);

The _input method should be overridden in all descendent
classes.  This method should accept character input and update
it's internal state information appropriately.  This method
will be used in both interactive and non-interactive modes to
send keystrokes to the widget.

=cut

sub _input {
	my $self = shift;
	my $input;
}

=head2 input

	$obj->input($string);

The input method provides a non-interactive method for sending input
to the widget.  This is essentially just a wrapper for the B<_input>
method, but will accept any number of string arguments at once.  It
splits all of the input into separate characters for feeding to the
B<_input> method.

=cut

sub input {
	my $self = shift;
	my @input = @_;
	my ($i, @char);

	while (defined ($i = shift @input)) {
		if (length($i) > 1) {
			@char = split(//, $i);
			foreach (@char) { $self->_input($_) };
		} else {
			$self->_input($i);
		}
	}
}

=head2 execute

	$obj->execute($mwh);

This method puts the widget into interactive mode, which consists of
calling the B<draw> method, scanning for keyboard input, feeding it
to the B<_input> method, and redrawing.

execute uses the widget's configuration information to allow easy
modification of its behavoiur.  First, it checks for the existance of
a INPUTFUNC key.  Setting its value to a subroutine reference allows
you to substitute any custom keyboard scanning/polling routine in leiu
of the default  B<scankey> provided by this module.

Second, it checks the return value of the input function against the
regular expression stored in FOCUSSWITCH, if any.  Any matches against
that expression will tell this method to exit, returning the key that
matches it.  This effectively causes the widget to 'lose focus'.

The only argument is a handle to a valid curses window object.

=cut

sub execute {
	my $self = shift;
	my $mwh = shift;
	my $conf = $self->{CONF};
	my $func = $$conf{'INPUTFUNC'} || \&scankey;
	my $regex = $$conf{'FOCUSSWITCH'};
	my $key;

	$self->draw($mwh, 1);

	while (1) {
		$key = &$func($mwh);
		return $key if (defined $regex && $key =~ /^[$regex]$/);
		$self->_input($key);
		$self->draw($mwh, 1);
	}
}

=head2 draw

	$obj->draw($mwh, 1);

The draw method should be overridden in each descendant class.  It
is reponsible for the rendering of the widget, and only that.  The first
argument is mandatory, being a valid window handle with which to create
the widget's derived window.  The second is optional, but if set to
true, will tell the widget to draw itself in an 'active' state.  For 
instance, the TextField widget will also render a cursor, while a 
ButtonSet widget will render the selected button in standout mode.

=cut

sub draw {
	my $self = shift;
	my $mwh = shift;
	my $active = shift;
}

=head2 getField

	$value = $obj->getField('VALUE');

The getField method retrieves the value(s) for every field requested
that exists in the configuration hash.

=cut

sub getField {
	my $self = shift;
	my @fields = shift;
	my $conf = $self->{CONF};
	my @results;

	foreach (@fields) {
		if (exists $$conf{$_}) {
			push(@results, $$conf{$_});
		} else {
			warn ref($self), ":  attempting to read a non-existent field!\n";
		}
	}

	return (scalar @results > 1) ? @results : $results[0];
}

=head2 setField

	$obj->setField(
		'FIELD1'	=> 1,
		'FIELD2'	=> 'value'
		);

The setField method sets the value for every key/value pair passed.

=cut

sub setField {
	my $self = shift;
	my %fields = (@_);
	my $conf = $self->{CONF};

	foreach (keys %fields) {
		if (exists $$conf{$_}) {
			$$conf{$_} = $fields{$_};
		} else {
			warn ref($self), ":  attempting to set a non-existent field\n";
		}
	}
}

1;

=head1 HISTORY

2001/07/05 -- First implementation of the base class.

=head1 AUTHOR/COPYRIGHT

(c) 2001 Arthur Corliss (corliss@digitalmages.com)

=cut

