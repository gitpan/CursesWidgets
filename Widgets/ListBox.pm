# Curses::Widgets::ListBox.pm -- List Box Widgets
#
# (c) 2001, Arthur Corliss <corliss@digitalmages.com>
#
# $Id: ListBox.pm,v 1.99 2001/12/05 09:54:17 corliss Exp $
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

Curses::Widgets::ListBox - List Box Widgets

=head1 MODULE VERSION

$Id: ListBox.pm,v 1.99 2001/12/05 09:54:17 corliss Exp $

=head1 SYNOPSIS

	use Curses::Widgets::ListBox;

	$lb = Curses::Widgets::ListBox->new({
		CAPTION			=> undef,
		CAPTIONCOL		=> undef,
		LENGTH			=> 10,
		LINES			=> 3,
		VALUE			=> 0,
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> 'red',
		FOCUSSWITCH		=> "\t",
		X			=> 1,
		Y			=> 1,
		TOPELEMENT		=> 0,
		LISTITEMS		=> [ @list ],
		});

	$lb->draw($mwh, 1);

	See the Curses::Widgets pod for other methods.

=head1 REQUIREMENTS

Curses
Curses::Widgets

=head1 DESCRIPTION

Curses::Widgets::ListBox provides simplified OO access to Curses-based
single/multi-select list boxes.  Each object maintains its own state 
information.

=cut

#####################################################################
#
# Environment definitions
#
#####################################################################

package Curses::Widgets::ListBox;

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

	$tm = Curses::Widgets::ListBox->new({
		CAPTION			=> undef,
		CAPTIONCOL		=> undef,
		LENGTH			=> 10,
		LINES			=> 3,
		VALUE			=> 0,
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> 'red',
		FOCUSSWITCH		=> "\t",
		X			=> 1,
		Y			=> 1,
		TOPELEMENT		=> 0,
		LISTITEMS		=> [ @list ],
		});

The new method instantiates a new ListBox object.  The only mandatory
key/value pairs in the configuration hash are B<X> and B<Y>.  All others
have the following defaults:

	Key		Default		Description
	============================================================
	CAPTION		undef		Caption superimposed on border
	CAPTIONCOL	undef		Foreground colour for caption 
					text
	LENGTH		10		Number of columns displayed
	LINES		3		Number of lines in the window
	VALUE		0		Current element selected
	INPUTFUNC	\&scankey	Function to use to scan for 
					keystrokes
	FOREGROUND	undef		Default foreground colour
	BACKGROUND	'black'		Default background colour
	BORDER		1		Display a border around the field
	BORDERCOL	undef		Foreground colour for border
	FOCUSSWITCH	"\t"		Characters which signify end of 
					input
	TOPELEMENT	0		Index of element displayed on 
					line 1
	LISTITEMS	[]		List of list items
	MULTISEL	0		Whether or not multiple items
					can be selected
	TOGGLE		"\n\s"		What input toggles selection of
					the current item
	SELECTED	0 or []		Index(es) of selected items
	CURSORPOS	0		Index of the item the cursor
					is currently on

The B<CAPTION> is only valid when the B<BORDER> is enabled.  If the border
is disabled, the field will be underlined, provided the terminal supports it.
The B<MAXLENGTH> has no effect if left undefined.

The value of B<SELECTED> should be an array reference when in multiple
selection mode.  Otherwise it should either undef or an integer.

=cut

sub _conf {
	# Validates and initialises the new ListBox object.
	#
	# Internal use only.

	my $self = shift;
	my %conf = ( 
		CAPTION			=> undef,
		CAPTIONCOL		=> undef,
		LENGTH			=> 10,
		LINES			=> 3,
		VALUE			=> 0,
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> undef,
		FOCUSSWITCH		=> "\t",
		TOPELEMENT		=> 0,
		LISTITEMS		=> [],
		MULTISEL		=> 0,
		SELECTED		=> undef,
		CURSORPOS		=> 0,
		TOGGLE			=> '\n\s',
		@_ 
		);
	my @required = qw( X Y );
	my $err = 0;

	# Check for required arguments
	foreach (@required) { $err = 1 unless exists $conf{$_} };

	# Make sure no errors are returned by the parent method
	$err = 1 unless $self->SUPER::_conf(%conf);

	# Update SELECTED depending on selection mode
	$conf{'SELECTED'} = [] if $conf{'MULTISEL'};

	return ($err == 0) ? 1 : 0;
}

=head2 draw

	$lb->draw($mwh, 1);

The draw method renders the list box in its current state.  This
requires a valid handle to a curses window in which it will render
itself.  The optional second argument, if true, will cause the field's
text cursor to be rendered as well.

=cut

sub draw {
	my $self = shift;
	my $mwh = shift;
	my $cursor = shift;
	my $conf = $self->{CONF};
	my ($y, $x) = @$conf{qw(Y X)};
	my ($cursorpos, $top) = @$conf{qw(CURSORPOS TOPELEMENT)};
	my $border = $$conf{'BORDER'};
	my $cols = $$conf{'LENGTH'};
	my $lines = $$conf{'LINES'};
	my @items = @{ $$conf{'LISTITEMS'} };
	my $sel = $$conf{'SELECTED'};
	my ($dwh, $i, $tmp);

	# Create a handle to the derived window area
	$dwh = $mwh->derwin($lines + (2 * $border), $cols + (2 * $border), 
		$y, $x);

	# Set the default foreground/background colour pair
	if ($$conf{'FOREGROUND'} && $$conf{'BACKGROUND'}) {
		$dwh->bkgdset(COLOR_PAIR(
			select_colour(@$conf{qw(FOREGROUND BACKGROUND)})));
	}

	# Erase the window
	$dwh->erase;

	# Turn on underlining (terminal-dependent) if no border is used
	$dwh->attron(A_UNDERLINE) unless $border;

	# Display the items on the list
	if (scalar @items) {
		
		# Adjust the cursor position if it's out of whack
		$cursorpos = $#items if $cursorpos > $#items;
		$top++ if $cursorpos - $top > $lines - 1;
		while ($top > $cursorpos) { --$top };

		# Display the items, in bold if selected in multi-select mode
		for $i ($top..$#items) {
			$dwh->attron(A_BOLD) if ($$conf{'MULTISEL'} &&
				grep /^$i$/, @$sel);
			$tmp = substr($items[$i], 0, $cols);
			$tmp .= ' ' x ($cols - length($tmp)) if length($tmp) < $cols;
			$dwh->addstr(0 + $border + $i - $top, 0 + $border, $tmp);
			$dwh->attroff(A_BOLD);
			last if $i - $top == $lines - 1;
		}

	} else {
		$$conf{'SELECTED'} = $$conf{'MULTISEL'} ? [] : undef;
	}

	# Render the border
	if ($$conf{'BORDER'}) {
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

		# Render up/down arrows as needed
		$dwh->addch(0, $cols, ACS_UARROW) if $top > 0;
		$dwh->addch($lines + 1, $cols, ACS_DARROW) if 
			$top + $lines < scalar @items ;
	}

	# Draw the cursor if necessary
	if ($cursor) {
		$tmp = substr($items[$cursorpos], 0, $cols);
		$tmp .= ' ' x ($cols - length($tmp)) if length($tmp) < $cols;
		$dwh->standout;
		$dwh->addstr(0 + $border + ($cursorpos - $top), 0 + $border,
			$tmp);
		$dwh->standend;
	}

	# Save any massaged values
	@$conf{qw(TOPELEMENT CURSORPOS SELECTED)} = ($top, $cursorpos, $sel);

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
	my $sel = $$conf{'SELECTED'};
	my @items = @{ $$conf{'LISTITEMS'} };
	my $pos = $$conf{'CURSORPOS'};
	my $re = $$conf{'TOGGLE'};

	# Process special keys
	if ($in eq KEY_UP) {
		if ($pos > 0) {
			--$pos;
		} else {
			beep;
		}
	} elsif ($in eq KEY_DOWN) {
		if ($pos < $#items) {
			++$pos;
		} else {
			beep;
		}
	} elsif ($in eq KEY_HOME || $in eq KEY_END || $in eq KEY_PPAGE ||
		$in eq KEY_NPAGE) {

		if (scalar @items) {
			if ($in eq KEY_HOME) {
				beep if $pos == 0;
				$pos = 0;
			} elsif ($in eq KEY_END) {
				beep if $pos == $#items;
				$pos = $#items;
			} elsif ($in eq KEY_PPAGE) {
				beep if $pos == 0;
				$pos -= $$conf{'LINES'};
				$pos = 0 if $pos < 0;
			} elsif ($in eq KEY_NPAGE) {
				beep if $pos == $#items;
				$pos += $$conf{'LINES'};
				$pos = $#items if $pos > $#items;
			}
		} else {
			beep;
		}

	# Process normal key strokes
	} else {
		
		# Exit out if there's no list to apply strokes to
		return unless scalar @items;

		if ($in =~ /^[$re]$/) {
			if ($$conf{'MULTISEL'}) {
				if (grep /^$pos$/, @$sel) {
					@$sel = grep  !/^$pos$/, @$sel;
				} else {
					push(@$sel, $pos);
				}
			} else {
				$sel = $pos;
			}
		} else {
			beep;
		}
	}

	# Save the changes
	@$conf{qw(CURSORPOS SELECTED)} = ($pos, $sel);
}

1;

=head1 HISTORY

1999/12/29 -- Original list box widget in functional model
2001/07/05 -- First incarnation in OO architecture

=head1 AUTHOR/COPYRIGHT

(c) 2001 Arthur Corliss (corliss@digitalmages.com)

=cut

