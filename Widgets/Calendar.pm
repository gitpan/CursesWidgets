# Curses::Widgets::Calendar.pm -- Button Set Widgets
#
# (c) 2001, Arthur Corliss <corliss@digitalmages.com>
#
# $Id: Calendar.pm,v 1.99 2001/12/05 09:54:06 corliss Exp $
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

Curses::Widgets::Calendar - Calendar Widgets

=head1 MODULE VERSION

$Id: Calendar.pm,v 1.99 2001/12/05 09:54:06 corliss Exp $

=head1 SYNOPSIS

	use Curses::Widgets::Calendar;

	$cal = Curses::Widgets::Calendar->({
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

	$cal->draw($mwh, 1);

	See the Curses::Widgets pod for other methods.

=head1 REQUIREMENTS

Curses
Curses::Widgets

=head1 DESCRIPTION

Curses::Widgets::Calendar provides simplified OO access to Curses-based
calendars.  Each object maintains it's own state information.

=cut

#####################################################################
#
# Environment definitions
#
#####################################################################

package Curses::Widgets::Calendar;

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

	$cal = Curses::Widgets::Calendar->({
		CAPTION			=> 'Appointments',
		CAPTIONCOL		=> 'yellow',
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> 'red',
		FOCUSSWITCH		=> "\t",
		X			=> 1,
		Y			=> 1,
		HIGHLIGHT		=> [12, 17, 25],
		HIGHLIGHTCOL		=> 'green',
		MONTH			=> '11/2001',
		});

The new method instantiates a new Calendar object.  The only mandatory
key/value pairs in the configuration hash are B<X> and B<Y>.  All
others have the following defaults:

	Key		Default		Description
	============================================================
	CAPTION		undef		Caption superimposed on border
	CAPTIONCOL	undef		Foreground colour for caption 
					text
	INPUTFUNC	\&scankey	Function to use to scan for 
					keystrokes
	FOREGROUND	undef		Default foreground colour
	BACKGROUND	'black'		Default background colour
	BORDER		1		Display a border around the field
	BORDERCOL	undef		Foreground colour for border
	FOCUSSWITCH	"\t"		Characters which signify end of 
					input
	HIGHLIGHT	[]		Days to highlight
	HIGHLIGHTCOL	undef		Default highlighted data colour
	MONTH		(current)	Month to display
	CURSORPOS	1		Day of the month where the cursor
					is

=cut

sub _conf {
	# Validates and initialises the new TextField object.
	#
	# Internal use only.

	my $self = shift;
	my %conf = ( 
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> undef,
		FOCUSSWITCH		=> "\t",
		HIGHLIGHT		=> [],
		HIGHLIGHTCOL		=> undef,
		CURSORPOS		=> 1,
		MONTH			=> join('/',
			(localtime)[4] + 1, (localtime)[5] + 1900),
		@_ 
		);
	my @required = qw( X Y );
	my $err = 0;

	# Check for required arguments
	foreach (@required) { $err = 1 unless exists $conf{$_} };

	$err = 1 unless $self->SUPER::_conf(%conf);

	return ($err == 0) ? 1 : 0;
}

=head2 draw

	$cal->draw($mwh, 1);

The draw method renders the calendar in its current state.  This
requires a valid handle to a curses window in which it will render
itself.  The optional second argument, if true, will cause the calendar's
selected day to be rendered in standout mode (inverse video).

=cut

sub draw {
	my $self = shift;
	my $mwh = shift;
	my $cursor = shift;
	my $conf = $self->{CONF};
	my ($y, $x) = @$conf{qw(Y X)};
	my $cursorpos = @$conf{'CURSORPOS'};
	my $border = $$conf{'BORDER'};
	my @date = split(/\//, $$conf{'MONTH'});
	my @highlight = @{ $$conf{'HIGHLIGHT'} };
	my ($dwh, $i, $j, $d, $tmp, @cal);

	# Create a handle to the derived window area
	$dwh = $mwh->derwin(8 + (2 * $border), 20 + (2 * $border), $y, $x);

	# Set the default foreground/background colour pair
	if ($$conf{'FOREGROUND'} && $$conf{'BACKGROUND'}) {
		$dwh->bkgdset(COLOR_PAIR(
			select_colour(@$conf{qw(FOREGROUND BACKGROUND)})));
	}

	# Erase the window
	$dwh->erase;

	# Get the calendar and adjust cursorpos if necessary
	@cal = _gen_cal(@date[1,0]);
	$d = 0;
	foreach $i (1..(scalar @cal)) {
		if (grep /^$cursorpos$/, @{ $cal[$i] }) {
			$d = 1;
			last;
		}
	}
	$cursorpos = 1 unless $d;

	# Display the calendar
	foreach $i (0..(scalar @cal)) {
		if ($i == 0) {
			$tmp = join(' ', @{ $cal[0] });
			$tmp = ' ' x int((20 - length($tmp)) / 2) . $tmp;
			$dwh->addstr($border, $border, $tmp);
		} else {
			$j = 0;
			foreach $d (@{ $cal[$i] }) {
				if ($d) {
					$j++ if length($d) == 1;
					$dwh->attrset(COLOR_PAIR(
						select_colour(@$conf{qw(HIGHLIGHTCOL BACKGROUND)})))
						if grep /^$d$/, @highlight;
					$dwh->standout if ($cursor && $d eq $cursorpos);
					$dwh->addstr($border + $i, $border + $j, $d);
					$dwh->standend if ($cursor && $d eq $cursorpos);
					$dwh->attrset(COLOR_PAIR(0));
					$j += (length($d) + 1);
				} else {
					$j += 3;
				}
			}
		}
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
			$dwh->addstr(0, 1, substr($$conf{'CAPTION'}, 0, 22));
		}
	}

	# Flush all of the changes to the console
	$mwh->touchwin;
	$mwh->refresh;
	$dwh->delwin;
}

sub _gen_cal {
	# Generates the calendar month output, and stuffs it into a
	# LOL, which is returned by the method.
	#
	# Modified from code provided courtesy of Michael E. Schechter,
	# <mschechter@earthlink.net>
	#
	# Internal use only.

	my @date = @_;
	my (@lines, @tmp, $i, @out);

	# All of these local subroutines are essentially code to replicate
	# the UNIX 'cal' command.  My code parses the output to create the 
	# LOL.

	local *print_month = sub {
		my ($year, $month) = @_;
		my @month = make_month_array($year, $month);
		my @months = ('', qw(January February March April May June 
			July August September October November December));
		my $days = 'Su Mo Tu We Th Fr Sa';
		my ($title, $diff, $left, $day, $end, $x, $out);

		$title = "$months[$month] $year";
		$diff = 20 - length($title);
		$left = $diff - int($diff / 2);
		$title = ' ' x $left."$title";
		$out = "$title\n$days";
		$end = 0;
		for ($x = 0; $x < scalar @month; $x++) {
			$out .= "\n" if $end == 0;
			$out .= "$month[$x]";
			$end++;
			if ($end > 6) {
				$end = 0;
			}
		}
		$out .= "\n";
		return $out;
	};

	local *make_month_array = sub {
		my ($year, $month) = @_;
		my $firstweekday = day_of_week_num($year, $month, 1);
		my (@month_array, $numdays, $remain, $x, $y);

		$numdays = days_in_month($year, $month);
		$y = 1;
		for ($x = 0; $x < $firstweekday; $x++ ) { $month_array[$x] = '   ' };
		if (! ($year == 1752 && $month == 9)) {
			for ($x = 1; $x <= $numdays; $x++, $y++) { 
				$month_array[$x + $firstweekday - 1] = sprintf( "%2d ", $y);
			}
		} else {
			for ($x = 1; $x <= $numdays; $x++, $y++) { 
				$month_array[$x + $firstweekday - 1] = sprintf( "%2d ", $y);
				if ($y == 2) {
					$y = 13;
				}
			}
		}
		return @month_array;
	};

	local *day_of_week_num = sub {
		my ($year, $month, $day) = @_;
		my ($a, $y, $m, $d);

		$a = int( (14 - $month)/12 );
		$y = $year - $a;
		$m = $month + (12 * $a) - 2;
		if (is_julian($year, $month)) {
			$d = (5 + $day + $y + int($y/4) + int(31*$m/12)) % 7;
		} else {
			$d = ($day + $y + int($y/4) - int($y/100) + int($y/400) + 
				int(31*$m/12)) % 7;
		}
		return $d;
	};

	local *days_in_month = sub {
		my ($year, $month) = @_;
		my @month_days = ( 0,31,28,31,30,31,30,31,31,30,31,30,31 );

		if ($month == 2 && is_leap_year($year)) {
			$month_days[2] = 29;
		} elsif ($year == 1752 && $month == 9) {
			$month_days[9] = 19;
		}
		return $month_days[$month];
	};

	local *is_julian = sub {
		my ($year, $month) = @_;
		my $bool = 0;

		$bool = 1 if ($year < 1752 || ($year == 1752 && $month <= 9));
		return $bool;
	};

	local *is_leap_year = sub {
		my $year = shift;
		my $bool = 0;

		if (is_julian($year, 1)) {
			$bool = 1 if ($year % 4 == 0);
		} else {
			$bool = 1 if (($year % 4 == 0 && $year % 100 != 0) || 
				$year % 400 == 0);
		}
		return $bool;
	};

	@lines = split(/\n/, print_month(@date));
	foreach (@lines) { 
		@tmp = split(/\s\s?/, $_);
		while (scalar @tmp > 7) { shift @tmp };
		push(@out, [ @tmp ]);
	}

	return @out;

}

sub _input {
	# Process input a keystroke at a time.
	#
	# Internal use only.

	my $self = shift;
	my $in = shift;
	my $conf = $self->{CONF};
	my $cursorpos = $$conf{'CURSORPOS'};
	my @date = split(/\//, $$conf{'MONTH'});
	my @days = (0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
	my $y;

	# Adjust for leap years, if necessary
	$days[2] += 1 if (($date[1] % 4 == 0 && $date[1] % 100 != 0) ||
		$date[1] % 400 == 0);

	# Navigate according to key press
	if ($in eq KEY_LEFT) {
		$cursorpos -= 1;
	} elsif ($in eq KEY_RIGHT) {
		$cursorpos += 1;
	} elsif ($in eq KEY_UP) {
		$cursorpos -= 7;
	} elsif ($in eq KEY_DOWN) {
		$cursorpos += 7;
	} elsif ($in eq KEY_NPAGE) {
		$cursorpos += 28;
		$cursorpos += 7 if $cursorpos <= $days[$date[0]];
	} elsif ($in eq KEY_PPAGE) {
		$cursorpos -= 28;
		$cursorpos -= 7 if $cursorpos > 0;
	} elsif ($in eq KEY_HOME || $in eq KEY_FIND) {
		($cursorpos, @date) = (localtime)[3..5];
		$date[0] += 1;
		$date[1] += 1900;
	}

	# Adjust the dates as necessary according to the cursorpos movement
	if ($cursorpos < 1) {
		--$date[0];
		if ($date[0] < 1) {
			--$date[1];
			$date[0] = 12;
		}
		$cursorpos += $days[$date[0]];
	} elsif ($cursorpos > $days[$date[0]]) {
		++$date[0];
		if ($date[0] > 12) {
			++$date[1];
			$date[0] = 1;
		}
		$cursorpos -= $days[$date[0] > 1 ? $date[0] - 1 : 12];
	}

	# Save the adjusted dates
	@$conf{qw(CURSORPOS MONTH)} = ($cursorpos, join('/', @date));
}

1;

=head1 HISTORY

1999/12/29 -- Original calendar widget in functional model
2001/07/05 -- First incarnation in OO architecture

=head1 AUTHOR/COPYRIGHT

(c) 2001 Arthur Corliss (corliss@digitalmages.com) 

=cut

