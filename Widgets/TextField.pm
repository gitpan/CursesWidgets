# Curses::Widgets::TextField.pm -- Text Field Widgets
#
# (c) 2001, Arthur Corliss <corliss@digitalmages.com>
#
# $Id: TextField.pm,v 1.99 2001/12/05 09:54:40 corliss Exp $
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

Curses::Widgets::TextField - Text Field Widgets

=head1 MODULE VERSION

$Id: TextField.pm,v 1.99 2001/12/05 09:54:40 corliss Exp $

=head1 SYNOPSIS

	use Curses::Widgets::TextField;

	$tf = Curses::Widgets::TextField->new({
		CAPTION			=> undef,
		CAPTIONCOL		=> undef,
		LENGTH			=> 10,
		MAXLENGTH		=> 255,
		MASK			=> undef,
		VALUE			=> '',
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> 'red',
		FOCUSSWITCH		=> "\t\n",
		CURSORPOS		=> 0,
		TEXTSTART		=> 0,
		PASSWORD		=> 0,
		X			=> 1,
		Y			=> 1,
		READONLY		=> 0,
		});

	$tf->draw($mwh, 1);

	See the Curses::Widgets pod for other methods.

=head1 REQUIREMENTS

Curses
Curses::Widgets

=head1 DESCRIPTION

Curses::Widgets::TextField provides simplified OO access to Curses-based
single line text fields.  Each object maintains its own state information.

=cut

#####################################################################
#
# Environment definitions
#
#####################################################################

package Curses::Widgets::TextField;

use strict;
use vars qw($VERSION @ISA);
use Curses;
use Curses::Widgets;

($VERSION) = (q$Revision: 1.99 $ =~ /(\d+(?:\.(\d+))+)/);
@ISA = qw( Curses::Widgets );

#####################################################################
#
# Module code follows
#
#####################################################################

=head1 METHODS

=head2 new (inherited from Curses::Widgets)

	$tf = Curses::Widgets::TextField->new({
		CAPTION			=> undef,
		CAPTIONCOL		=> undef,
		LENGTH			=> 10,
		MAXLENGTH		=> 255,
		MASK			=> undef,
		VALUE			=> '',
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> 'red',
		FOCUSSWITCH		=> "\t\n",
		CURSORPOS		=> 0,
		TEXTSTART		=> 0,
		PASSWORD		=> 0,
		X			=> 1,
		Y			=> 1,
		READONLY		=> 0,
		});

The new method instantiates a new TextField object.  The only mandatory
key/value pairs in the configuration hash are B<X> and B<Y>.  All others
have the following defaults:

	Key		Default		Description
	============================================================
	CAPTION		undef		Caption superimposed on border
	CAPTIONCOL	undef		Foreground colour for caption 
					text
	LENGTH		10		Number of columns displayed
	MAXLENGTH	255		Maximum string length allowed
	MASK		undef		Not yet implemented
	VALUE		''		Current field text
	INPUTFUNC	\&scankey	Function to use to scan for 
					keystrokes
	FOREGROUND	undef		Default foreground colour
	BACKGROUND	'black'		Default background colour
	BORDER		1		Display a border around the 
					field
	BORDERCOL	undef		Foreground colour for border
	FOCUSSWITCH	"\t\n"		Characters which signify end of 
					input
	CURSORPOS	0		Starting position of the cursor
	TEXTSTART	0		Position in string to start 
					displaying
	PASSWORD	0		Subsitutes '*' instead of 
					characters
	READONLY	0		Prevents alteration to content

The B<CAPTION> is only valid when the B<BORDER> is enabled.  If the border
is disabled, the field will be underlined, provided the terminal supports it.

If B<MAXLENGTH> is undefined, no limit will be placed on the string length.

=cut

sub _conf {
	# Validates and initialises the new TextField object.
	#
	# Internal use only.

	my $self = shift;
	my %conf = ( 
		CAPTION			=> undef,
		CAPTIONCOL		=> undef,
		LENGTH			=> 10,
		MAXLENGTH		=> 255,
		MASK			=> undef,
		VALUE			=> '',
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> undef,
		FOCUSSWITCH		=> "\t\n",
		CURSORPOS		=> 0,
		TEXTSTART		=> 0,
		PASSWORD		=> 0,
		READONLY		=> 0,
		@_ 
		);
	my @required = qw( X Y );
	my $err = 0;

	# Check for required arguments
	foreach (@required) { $err = 1 unless exists $conf{$_} };

	# Make sure no errors are returned by the parent method
	$err = 1 unless $self->SUPER::_conf(%conf);

	return ($err == 0) ? 1 : 0;
}

=head2 draw

	$tf->draw($mwh, 1);

The draw method renders the text field in its current state.  This
requires a valid handle to a curses window in which it will render
itself.  The optional second argument, if true, will cause the field's
text cursor to be rendered as well.

=cut

sub draw {
	my $self = shift;
	my $mwh = shift;
	my $cursor = shift;
	my $conf = $self->{CONF};
	my ($y, $x, $ro, $border, $pos, $ts, $value) = 
		@$conf{qw(Y X READONLY BORDER CURSORPOS TEXTSTART VALUE)};
	my $cols = $$conf{'LENGTH'} + (2 * $border);
	my $lines = 1 + (2 * $border);
	my ($dwh, $ch, $seg);

	# Create a handle to the derived window area
	$dwh = $mwh->derwin($lines, $cols, $y, $x);

	# Set the default foreground/background colour pair
	if ($$conf{'FOREGROUND'} && $$conf{'BACKGROUND'}) {
		$dwh->bkgdset(COLOR_PAIR(
			select_colour(@$conf{qw(FOREGROUND BACKGROUND)})));
	}

	# Trim the value if it exceeds the maximum length
	$value = substr($value, 0, $$conf{'MAXLENGTH'});

	# Erase the window
	$dwh->erase;

	# Turn on underlining (terminal-dependent) if no border is used
	$dwh->attron(A_UNDERLINE) unless $border;

	# Adjust the cursor position and text start if it's out of whack
	if ($pos > length($value)) {
		$pos = length($value);
	} elsif ($pos < 0) {
		$pos = 0;
	}
	if ($pos > $ts + $$conf{'LENGTH'} - 1) {
		$ts = $pos + 1 - $$conf{'LENGTH'};
	} elsif ($pos < $ts) {
		$ts = $pos;
	}
	$ts = 0 if $ts < 0;

	# Write the widget value (adjusting for horizontal scrolling)
	$seg = substr($value, $ts, $$conf{'LENGTH'});
	$seg = '*' x length($seg) if $$conf{'PASSWORD'};
	$seg .= ' ' x ($$conf{'LENGTH'} - length($seg));
	$dwh->addstr(0 + $border, 0 + $border, $seg);

	# Render the border
	if ($border) {
		if (defined $$conf{'BORDERCOL'}) {
			$dwh->attrset(COLOR_PAIR(
				select_colour(@$conf{qw(BORDERCOL BACKGROUND)})));
			$dwh->attron(A_BOLD) if $$conf{'BORDERCOL'} eq 'yellow';
		}
		$dwh->box(ACS_VLINE, ACS_HLINE);

		# Render the caption
		if (defined $$conf{'CAPTION'}) {
			$dwh->attrset(COLOR_PAIR(
				select_colour(@$conf{qw(CAPTIONCOL BACKGROUND)})))
				if $$conf{'CAPTIONCOL'};
			$dwh->attron(A_BOLD) if $$conf{'CAPTIONCOL'} eq 'yellow';
			$dwh->addstr(0, 1, substr($$conf{'CAPTION'}, 0, 
				$$conf{'LENGTH'}));
		}
	}

	# Draw the cursor if necessary
	if ($cursor && ! $ro) {
		if (length($value) > 0) {
			if ($pos < length($value)) {
				$ch = substr($value, $pos, 1);
				$ch = '*' if $$conf{'PASSWORD'};
			} else {
				$ch = ' ';
			}
		} else {
			$ch = ' ';
			$pos = 0;
		}
		$dwh->standout;
		$dwh->addstr(0 + $border, 0 + ($pos - $ts) + $border, $ch);
		$dwh->standend;
	}

	# Save the textstart, cursorpos, and value in case it was tweaked
	@$conf{qw(TEXTSTART CURSORPOS VALUE)} = ($ts, $pos, $value);

	# Flush all of the changes to the console
	$mwh->touchwin;
	$mwh->refresh;
	$dwh->delwin;
}

sub _input {
	# Process input a keystroke at a time.
	#
	# Internal use only.

	my $self = shift;
	my $in = shift;
	my $conf = $self->{CONF};
	my $mask = $$conf{'MASK'};
	my ($value, $pos, $max, $ro) = 
		@$conf{qw(VALUE CURSORPOS MAXLENGTH READONLY)};
	my @string = split(//, $value);

	# Process special keys
	if ($in eq KEY_BACKSPACE) {
		return if $ro;
		if ($pos > 0) {
			splice(@string, $pos - 1, 1);
			$value = join('', @string);
			--$pos;
		} else {
			beep;
		}
	} elsif ($in eq KEY_RIGHT) {
		$pos < length($value) ? ++$pos : beep;
	} elsif ($in eq KEY_LEFT) {
		$pos > 0 ? --$pos : beep;
	} elsif ($in eq KEY_HOME) {
		$pos = 0;
	} elsif ($in eq KEY_END) {
		$pos = length($value);

	# Process other keys
	} else {

		return if $ro;

		# Exit if it's a non-printing character
		return unless $in =~ /^[\w\W]$/;

		# Reject if we're already at the max length
		if (defined $max && length($value) == $max) {
			beep;
			return;

		# Append to the end if the cursor's at the end
		} elsif ($pos == length($value)) {
			$value .= $in;

		# Insert the character at the cursor's position
		} elsif ($pos > 0) {
			@string = (@string[0..($pos - 1)], $in, @string[$pos..$#string]);
			$value = join('', @string);

		# Insert the character at the beginning of the string
		} else {
			$value = "$in$value";
		}

		# Increment the cursor's position
		++$pos;
	}

	# Save the changes
	@$conf{qw(VALUE CURSORPOS)} = ($value, $pos);
}

1;

=head1 HISTORY

1999/12/29 -- Original text field widget in functional model
2001/07/05 -- First incarnation in OO architecture

=head1 AUTHOR/COPYRIGHT

(c) 2001 Arthur Corliss (corliss@digitalmages.com) 

=cut

