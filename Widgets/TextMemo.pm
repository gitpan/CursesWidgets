# Curses::Widgets::TextMemo.pm -- Text Memo Widgets
#
# (c) 2001, Arthur Corliss <corliss@digitalmages.com>
#
# $Id: TextMemo.pm,v 1.100 2001/12/10 10:54:35 corliss Exp $
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

Curses::Widgets::TextMemo - Text Memo Widgets

=head1 MODULE VERSION

$Id: TextMemo.pm,v 1.100 2001/12/10 10:54:35 corliss Exp $

=head1 SYNOPSIS

	use Curses::Widgets::TextMemo;

	$tm = Curses::Widgets::TextMemo->new({
		CAPTION			=> undef,
		CAPTIONCOL		=> undef,
		LENGTH			=> 10,
		MAXLENGTH		=> undef,
		LINES			=> 3,
		MASK			=> undef,
		VALUE			=> '',
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> 'red',
		FOCUSSWITCH		=> "\t",
		CURSORPOS		=> 0,
		TEXTSTART		=> 0,
		PASSWORD		=> 0,
		X				=> 1,
		Y				=> 1,
		READONLY		=> 0,
		});

	$tm->draw($mwh, 1);

	See the Curses::Widgets pod for other methods.

=head1 REQUIREMENTS

=over

=item Curses

=item Curses::Widgets

=back

=head1 DESCRIPTION

Curses::Widgets::TextMemo provides simplified OO access to Curses-based
single line text fields.  Each object maintains its own state information.

=cut

#####################################################################
#
# Environment definitions
#
#####################################################################

package Curses::Widgets::TextMemo;

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

	$tm = Curses::Widgets::TextMemo->new({
		CAPTION			=> undef,
		CAPTIONCOL		=> undef,
		LENGTH			=> 10,
		MAXLENGTH		=> undef,
		LINES			=> 3,
		MASK			=> undef,
		VALUE			=> '',
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> 'red',
		FOCUSSWITCH		=> "\t",
		CURSORPOS		=> 0,
		TEXTSTART		=> 0,
		PASSWORD		=> 0,
		X			=> 1,
		Y			=> 1,
		READONLY		=> 0,
		});

The new method instantiates a new TextMemo object.  The only mandatory
key/value pairs in the configuration hash are B<X> and B<Y>.  All others
have the following defaults:

	Key		Default		Description
	============================================================
	CAPTION		undef		Caption superimposed on border
	CAPTIONCOL	undef		Foreground colour for caption 
					text
	LENGTH		10		Number of columns displayed
	MAXLENGTH	undef		Maximum string length allowed
	LINES		3		Number of lines in the window
	VALUE		''		Current field text
	INPUTFUNC	\&scankey	Function to use to scan for 
					keystrokes
	FOREGROUND	undef		Default foreground colour
	BACKGROUND	'black'		Default background colour
	BORDER		1		Display a border around the field
	BORDERCOL	undef		Foreground colour for border
	FOCUSSWITCH	"\t"		Characters which signify end of 
					input
	CURSORPOS	0		Starting position of the cursor
	TEXTSTART	0		Line number of string to start 
					displaying
	PASSWORD	0		Subsitutes '*' instead of 
					characters
	READONLY	0		Prevents alteration to content

The B<CAPTION> is only valid when the B<BORDER> is enabled.  If the border
is disabled, the field will be underlined, provided the terminal supports it.
The B<MAXLENGTH> has no effect if left undefined.

=cut

sub _conf {
	# Validates and initialises the new TextMemo object.
	#
	# Internal use only.

	my $self = shift;
	my %conf = ( 
		CAPTION			=> undef,
		CAPTIONCOL		=> undef,
		LENGTH			=> 10,
		MAXLENGTH		=> undef,
		LINES			=> 3,
		VALUE			=> '',
		INPUTFUNC		=> \&scankey,
		FOREGROUND		=> undef,
		BACKGROUND		=> 'black',
		BORDER			=> 1,
		BORDERCOL		=> undef,
		UNDERLINE		=> 1,
		FOCUSSWITCH		=> "\t",
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

	$tm->draw($mwh, 1);

The draw method renders the text memo in its current state.  This
requires a valid handle to a curses window in which it will render
itself.  The optional second argument, if true, will cause the field's
text cursor to be rendered as well.

=cut

sub draw {
	my $self = shift;
	my $mwh = shift;
	my $cursor = shift;
	my $conf = $self->{CONF};
	my ($border, $ro, $ts, $pos, $value) = 
		@$conf{qw(BORDER READONLY TEXTSTART CURSORPOS VALUE)};
	my ($y, $x) = @$conf{qw(Y X)};
	my $cols = $$conf{'LENGTH'};
	my $lines = $$conf{'LINES'};
	my ($dwh, $ch, @lines, $line, $tmp, $chx, $chy);
	my ($maxline);

	# Create a handle to the derived window area
	$dwh = $mwh->derwin($lines + (2 * $border), $cols + (2 * $border), $y, $x);

	# Set the default foreground/background colour pair
	if ($$conf{'FOREGROUND'} && $$conf{'BACKGROUND'}) {
		$dwh->bkgdset(COLOR_PAIR(
			select_colour(@$conf{qw(FOREGROUND BACKGROUND)})));
	}

	# Trim the value if it exceeds the maximum length
	$value = substr($value, 0, $$conf{'MAXLENGTH'}) if
		defined $$conf{'MAXLENGTH'};

	# Break text into lines
	@lines = textwrap($value, $$conf{'LENGTH'});

	# Erase the window
	$dwh->erase;

	# Turn on underlining (terminal-dependent) if no border is used
	$dwh->attron(A_UNDERLINE) unless ($border || ! $$conf{'UNDERLINE'});

	# Adjust the cursor position and text start line if they're out of whack
	if ($pos < 0) {
		$pos = 0 if $pos < 0;
	} elsif ($pos > length($value)) {
		$pos = length($value);
	}
	if ($ts > $#lines) {
		$ts = $#lines;
	} elsif ($ts < 0) {
		$ts = 0;
	}

	# Adjust the text start position if the cursor position is out
	# of bounds, and calculate the relative cursor x and y positions
	$chy = $chx = $tmp = 0;
	$maxline = $ts + $$conf{'LINES'} - 1;
	$maxline = $maxline > $#lines ? $#lines : $maxline;
	if (scalar @lines) {

		$tmp = length(join('', @lines[0..($ts - 1)])) - 1;

		# Cursor position has moved above the displayed lines
		if ($pos <= $tmp) {
			until ($pos > $tmp) {
				--$ts;
				$tmp = length(join('', @lines[0..($ts - 1)])) - 1;
			}
			$chy = 0;
			$chx = $pos - $tmp - 1;

		# Cursor position is either in or below the window
		} else {

			$tmp = length(join('', @lines[0..$maxline])) - 1;

			# Cursor position is below the window
			if ($pos > $tmp) {
				until ($pos <= $tmp + 1) {
					++$ts;
					$maxline += ($maxline < $#lines) ? 1 : 0;
					$tmp = length(join('', @lines[0..$maxline])) - 1;
				}
				$chy = $maxline - $ts;
				$chx = $pos - ($tmp - length($lines[$maxline]) + 1);

			# Cursor is inside the displayed window
			} else {
				$chy = $maxline;
				until ($pos > $tmp) {
					$tmp -= length($lines[$chy]);
					--$chy;
				}
				$chy -= ($ts - 1);
				$chx = $pos - $tmp - 1;
			}
		}

		# Bump the cursor to the next line for newline characters or
		# if the cursor position exceeds the line length
		if ($chx == $$conf{'LENGTH'}) {
			++$chy;
			$chx = 0;
		}

		# Move the entire displayed window down one line if chy exceeds it 
		if ($chy == $$conf{'LINES'}) {
			++$ts;
			--$chy;
		}

	} else {
		$ts = 0;
	}

	# Write the widget value
	$tmp = 0;
	foreach (1..$$conf{'LINES'}) {
		if ($ts + $_ - 1 <= $#lines) {
			chomp($lines[$ts + $_ - 1]);
			$lines[$ts + $_ - 1] .= ' ' x ($$conf{'LENGTH'} - 
				length($lines[$ts + $_ - 1]));
			$dwh->addstr(0 + $border + $tmp, 0 + $border, 
				$lines[$ts + $_ - 1]);
		} else {
			$dwh->addstr(0 + $border + $tmp, 0 + $border, 
				' ' x $$conf{'LENGTH'});
		}
		++$tmp;
	}

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

		# Render up/down arrows as needed
		$dwh->addch(0, $cols, ACS_UARROW) if $ts > 0;
		$dwh->addch($lines + 1, $cols, ACS_DARROW) if 
			$ts + $lines < scalar @lines ;
	}

	# Draw the cursor if necessary
	if ($cursor && ! $ro) {
		if (length($value) > 0) {
			if ($pos < length($value)) {
				$ch = substr($value, $pos, 1);
				$ch = ' ' if $ch eq "\n";
			} else {
				$ch = ' ';
			}
		} else {
			$ch = ' ';
		}
		$dwh->standout;
		$dwh->addstr(0 + $border + $chy, 
			0 + $chx + $border, $ch);
		$dwh->standend;
	}

	# Store textstart, cursorpos, and value in case it had to be adjusted
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
	my ($value, $pos, $max, $ro, $ts) = 
		@$conf{qw(VALUE CURSORPOS MAXLENGTH READONLY TEXTSTART)};
	my @string = split(//, $value);
	my @lines = textwrap($value, $$conf{'LENGTH'});
	my ($snippet, $i, $lpos, $l);

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
	} elsif ($in eq KEY_UP || $in eq KEY_DOWN ||
		$in eq KEY_NPAGE || $in eq KEY_PPAGE) {

		# Get the text length up to the displayed window
		$snippet = $ts == 0 ? 0 : length(join('', @lines[0..($ts - 1)]));

		# Get the position of the cursor relative to the line it's on,
		# as well as the line index
		$i = 0;
		while ($snippet + length($lines[$ts + $i]) < $pos) {
			$snippet += length($lines[$ts + $i]);
			++$i;
		}
		$l = $ts + $i;
		$lpos = $pos - $snippet;

		# Process according to the key
		if ($in eq KEY_UP) {
			if ($l > 0) {
				if (length($lines[$l - 1]) > $lpos) {
					$pos -= length($lines[$l - 1]);
				} else {
					$pos -= ($lpos + 1);
				}
			} else {
				beep;
			}
		} elsif ($in eq KEY_DOWN) {
			if ($l < $#lines) {
				if (length($lines[$l + 1]) > $lpos) {
					$pos += length($lines[$l]);
				} else {
					$pos += ((length($lines[$l]) - $lpos) + 
						length($lines[$l + 1]) - 1);
				}
			} else {
				beep;
			}
		} elsif ($in eq KEY_PPAGE) {
			if ($l >= $$conf{'LINES'}) {
				$pos -= length(join('', 
					@lines[(1 + $l - $$conf{'LINES'})..($l - 1)]));
				if (length($lines[$l - $$conf{'LINES'}]) > $lpos) {
					$pos -= length($lines[$l - $$conf{'LINES'}]);
				} else {
					$pos -= ($lpos + 1);
				}
			} elsif ($l > 0) {
				if ($lpos > length($lines[0])) {
					$pos = length($lines[0]) - 1;
				} else {
					$pos = $lpos;
				}
			} else {
				beep;
			}
		} elsif ($in eq KEY_NPAGE) {
			if ($l <= $#lines - $$conf{'LINES'}) {
				$pos += length(join('', 
					@lines[($l + 1) ..($l + $$conf{'LINES'} - 1)]));
				if (length($lines[$l + $$conf{'LINES'}]) >= $lpos) {
					$pos += (length($lines[$l + $$conf{'LINES'}]) + 1);
				} else {
					$pos += ((length($lines[$l]) - $lpos) + 
						length($lines[$l + $$conf{'LINES'}]) - 1);
				}
			} elsif ($l < $#lines) {
				if (length($lines[$#lines]) > $lpos) {
					$pos = length($value) - (length($lines[$#lines]) -
						$lpos);
				} else {
					$pos = length($value);
				}
			} else {
				beep;
			}
		}

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
	@$conf{qw(VALUE CURSORPOS TEXTSTART)} = ($value, $pos, $ts);
}

1;

=head1 HISTORY

1999/12/29 -- Original text field widget in functional model
2001/07/05 -- First incarnation in OO architecture

=head1 AUTHOR/COPYRIGHT

(c) 2001 Arthur Corliss (corliss@digitalmages.com) 

=cut

