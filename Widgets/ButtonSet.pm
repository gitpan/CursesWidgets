# Curses::Widgets::ButtonSet.pm -- Button Set Widgets
#
# (c) 2001, Arthur Corliss <corliss@digitalmages.com>
#
# $Id: ButtonSet.pm,v 1.100 2001/12/10 10:49:13 corliss Exp $
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

Curses::Widgets::ButtonSet - Button Set Widgets

=head1 MODULE VERSION

$Id: ButtonSet.pm,v 1.100 2001/12/10 10:49:13 corliss Exp $

=head1 SYNOPSIS

	use Curses::Widgets::ButtonSet;

	$btns = Curses::Widgets::ButtonSet->({
		LENGTH			=> 10,
		VALUE			=> 0,
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> undef,
		FOCUSSWITCH		=> "\t\n",
		HORIZONTAL		=> 1,
		PADDING			=> 1,
		X			=> 1,
		Y			=> 1,
		LABELS			=> [ qw( OK CANCEL ) ],
		});

	$btns->draw($mwh, 1);

	See the Curses::Widgets pod for other methods.

=head1 REQUIREMENTS

=over

=item Curses

=item Curses::Widgets

=back

=head1 DESCRIPTION

Curses::Widgets::ButtonSet provides simplified OO access to Curses-based
button sets.  Each object maintains it's own state information.

=cut

#####################################################################
#
# Environment definitions
#
#####################################################################

package Curses::Widgets::ButtonSet;

use strict;
use vars qw($VERSION @ISA);
use Carp;
use Curses;
use Curses::Widgets;

($VERSION) = (q$Revision: 1.100 $ =~ /(\d+(?:\.(\d+))+)/);
@ISA = qw( Curses::Widgets );

#####################################################################
#
# Module code follows
#
#####################################################################

=head1 METHODS

=head2 new (inherited from Curses::Widgets)

	$btns = Curses::Widgets::ButtonSet->({
		LENGTH			=> 10,
		VALUE			=> 0,
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> undef,
		FOCUSSWITCH		=> "\t\n",
		HORIZONTAL		=> 1,
		PADDING			=> 1,
		X			=> 1,
		Y			=> 1,
		LABELS			=> [ qw( OK CANCEL ) ],
		});

The new method instantiates a new ButtonSet object.  The only mandatory
key/value pairs in the configuration hash are B<X>, B<Y>, and B<LABELS>.  All
others have the following defaults:

	Key		Default		Description
	============================================================
	LENGTH		10		Number of columns for each 
					button label
	VALUE		0		Button selected (0-based 
					indexing)
	INPUTFUNC	\&scankey	Function to use to scan for 
					keystrokes
	FOREGROUND	undef		Default foreground colour
	BACKGROUND	'black'		Default blackground colour
	BORDER		1		Display border around the set
	BORDERCOL	undef		Foreground colour for border
	FOCUSSWITCH	"\t\n"		Characters which signify end of 
					input
	HORIZONTAL	1		Horizontal orientation for set
	PADDING		1		Number of spaces between buttons

The last option, B<PADDING>, is only applicable to horizontal sets without
borders.

=cut

sub _conf {
	# Validates and initialises the new TextField object.
	#
	# Internal use only.

	my $self = shift;
	my %conf = ( 
		LENGTH			=> 10,
		VALUE			=> 0,
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> undef,
		FOCUSSWITCH		=> "\t\n",
		HORIZONTAL		=> 1,
		PADDING			=> 1,
		@_ 
		);
	my @required = qw( X Y LABELS );
	my $err = 0;

	# Check for required arguments
	foreach (@required) { $err = 1 unless exists $conf{$_} };

	$err = 1 unless $self->SUPER::_conf(%conf);

	return ($err == 0) ? 1 : 0;
}

=head2 draw

	$btns->draw($mwh, 1);

The draw method renders the button set in its current state.  This
requires a valid handle to a curses window in which it will render
itself.  The optional second argument, if true, will cause the set's
selected button to be rendered in standout mode (inverse video).

=cut

sub draw {
	my $self = shift;
	my $mwh = shift;
	my $active = shift;
	my $conf = $self->{CONF};
	my ($y, $x, $hz, $value, $length) = 
		@$conf{qw(Y X HORIZONTAL VALUE LENGTH)};
	my @labels = @{ $$conf{'LABELS'} };
	my $border = $$conf{'BORDER'};
	my ($dwh, $lines, $cols, $i, $j, $l);

	# Calculate the derived window dimensions
	if ($hz) {
		$cols = $length * scalar @labels;
		$cols += ($border ? scalar @labels + 1 : 
			(scalar @labels * 2) + ($$conf{'PADDING'} ? (scalar @labels - 1) *
			$$conf{'PADDING'} : 0));
		$lines = $border ? 3 : 1;
	} else {
		$cols = $length + 2;
		$lines = $border ? scalar @labels * 2 + 1 : scalar @labels;
	}

	# Create a handle to the derived window area
	$dwh = $mwh->derwin($lines, $cols, $y, $x);

	# Set the default foreground/background colour pair
	if ($$conf{'FOREGROUND'} && $$conf{'BACKGROUND'}) {
		$dwh->bkgdset(COLOR_PAIR(
			select_colour(@$conf{qw(FOREGROUND BACKGROUND)})));
	}

	# Erase the window
	$dwh->erase;

	# Draw the labels
	$i = $border ? 1 : 0;
	for ($l = 0; $l < scalar @labels; $l++) {
		$labels[$l] = substr($labels[$l], 0, $length);
		if ($border) {
			$j = ' ' x int(($length - length($labels[$l])) / 2) . $labels[$l];
			$j .= ' ' x ($length - length($j));
		} else {
			$j = '<' . ' ' x int(($length - length($labels[$l])) / 2) . 
				$labels[$l];
			$j .= ' ' x (1 + $length - length($j)) . '>';
		}
		$dwh->standout if ($active && $l == $value);
		if ($hz) {
			$dwh->addstr(0 + $border, $i, $j);
			$i += $border ? $length + 1 : $length + 2 +
				$$conf{'PADDING'};
		} else {
			$dwh->addstr($i, 0 + $border, $j);
			$i += $border ? 2 : 1;
		}
		$dwh->standend if ($active && $l == $value);
	}

	# Draw the border
	if ($border) {
		if (defined $$conf{'BORDERCOL'}) {
			$dwh->attrset(COLOR_PAIR(
				select_colour(@$conf{qw(BORDERCOL BACKGROUND)})));
			$dwh->attron(A_BOLD) if $$conf{'BORDERCOL'} eq 'yellow';
		}
		$dwh->box(ACS_VLINE, ACS_HLINE);
		if ($hz) {
			$i = $length + 1;
			until ($i == $cols - 1) {
				$dwh->addch(0, $i, ACS_TTEE);
				$dwh->addch(1, $i, ACS_VLINE);
				$dwh->addch(2, $i, ACS_BTEE);
				$i += ($length + 1);
			}
		} else {
			$i = 2;
			until ($i == $lines - 1) {
				$dwh->addch($i, 0, ACS_LTEE);
				for ($j = 1; $j <= $length; $j++) {
					$dwh->addch($i, $j, ACS_HLINE) };
				$dwh->addch($i, $length + 1, ACS_RTEE);
				$i += 2;
			}
		}
	}

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
	my ($value, $hz) = @$conf{qw(VALUE HORIZONTAL)};
	my $num = scalar @{ $$conf{'LABELS'} };

	if ($hz) {
		if ($in eq KEY_RIGHT) {
			++$value;
			$value = 0 if $value == $num;
		} elsif ($in eq KEY_LEFT) {
			--$value;
			$value = ($num - 1) if $value == -1;
		} else {
			beep;
		}
	} else {
		if ($in eq KEY_UP) {
			--$value;
			$value = ($num - 1) if $value == -1;
		} elsif ($in eq KEY_DOWN) {
			++$value;
			$value = 0 if $value == $num;
		} else {
			beep;
		}
	}

	$$conf{'VALUE'} = $value;
}

1;

=head1 HISTORY

1999/12/29 -- Original button set widget in functional model
2001/07/05 -- First incarnation in OO architecture

=head1 AUTHOR/COPYRIGHT

(c) 2001 Arthur Corliss (corliss@digitalmages.com)

=cut

