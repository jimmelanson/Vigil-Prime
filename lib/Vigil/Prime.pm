package Vigil::Prime;

use 5.010;
use Carp qw(carp confess cluck);
use constant MAX_SEED => 9223372036854775807;
our $VERSION = '1.1.0';

sub new {
    my ($class, $start, $end, %opts) = @_;
    confess "Seed cannot be negative" if defined $start && $start < 0;

    if( ($start >= MAX_SEED) || ( defined $end && $end >= MAX_SEED) ) {
		confess "Either the seed or the max limit value exceeds the maximum value for an integer. The object was not created.";
	}
	
    my $DEFAULT_LIMIT = 100_000;         # default sieve size
    my $WARN_LIMIT    = 1_000_000_000;   # warn above this
    my $HARD_LIMIT    = 10_000_000_000;  # default hard stop
	
    my $ignore_limits = $opts{ignore_limits} // 0;

    $start //= 2;
    $end   //= $DEFAULT_LIMIT;

    if (!$ignore_limits) {
        if ($end - $start > $HARD_LIMIT) {
            die sprintf(
                "Requested range (%s to %s) exceeds the hard limit of %s numbers.\n Tip: Use 'ignore_limits => 1' if you understand the memory/time cost.\n",
                $start, $end, $HARD_LIMIT
            );
        }

        if ($end - $start > $WARN_LIMIT) {
            cluck sprintf(
                "Warning: Large sieve requested (%s to %s). This may use ~%.2f MB RAM.\n Consider processing in chunks <= %s for speed.\n",
                $start, $end,
                ($end - $start) / 8 / 1024 / 1024,
                $WARN_LIMIT
            );
        }
    }
    cluck "Ignoring sieve size limits — expect high memory/time usage.\n" if $ignore_limits;

    my $self = {
        _seed => $start, 
		_sieve_limit => $end,
		_bitpacked_sieve => '',
        _bitpacked_sieve_list => [],
        _range_from => undef,
        _range_to => undef,
    };
    bless $self, $class;

	$self->{_bitpacked_sieve} = $self->_generate_bitpacked_sieve($self->{_sieve_limit});

    return $self;
}

sub seed { 
    my ($self, $value) = @_;
    if (defined $value) {
		$value = MAX_SEED if $value > MAX_SEED; #Cap max seed to 2^63 - 1
        #$self->{_seed} = $value >= 2 ? $value : 2;  # enforce minimum seed 2
        $self->{_seed} = $value < 0 ? 0 : $value;  # enforce minimum seed 0
    }
    return $self->{_seed};
}

sub sieve_list {
    my ($self) = @_;
    # Return a copy of the list as an array
    return @{ $self->{_bitpacked_sieve_list} };
}

sub range {
    my ($self, $num_from, $num_to) = @_;

	#Set minimums
	$num_from = 2 if $num_from < 2;
	$num_to = 3 if $num_to < 3;

	#If the second number is lower than the first number
	($num_from, $num_to) = ($num_to, $num_from) if $num_to < $num_from;

    # Validate range
	if ($num_from == $num_to) {
		carp "Range start and end are equal.";
		return $self->_is_prime($num_from) ? ($num_from) : ();
	}

	$self->{_range_from} = $num_from;
	$self->{_range_to}   = $num_to;

    my @primes;

    # If the range is fully within the sieve, use the prebuilt list
    if ($num_to <= $self->{_sieve_limit}) {
        my $list = $self->{_bitpacked_sieve_list};

        # Binary search to find first prime >= num_from
        my ($lo, $hi) = (0, $#$list);
        while ($lo <= $hi) {
            my $mid = int(($lo + $hi)/2);
            if ($list->[$mid] < $num_from) { $lo = $mid + 1 }
            else { $hi = $mid - 1 }
        }
        my $start_index = $lo;

        # Binary search to find last prime <= num_to
        ($lo, $hi) = (0, $#$list);
        while ($lo <= $hi) {
            my $mid = int(($lo + $hi)/2);
            if ($list->[$mid] <= $num_to) { $lo = $mid + 1 }
            else { $hi = $mid - 1 }
        }
        my $end_index = $hi;

        if ($start_index <= $end_index) {
            @primes = @$list[$start_index .. $end_index];
        }

        return wantarray ? @primes : scalar @primes;
    }

    # Fallback for ranges extending beyond the sieve
    # Include 2 if in range
    push @primes, 2 if $num_from <= 2 && $num_to >= 2;

    # Start from next odd number >= num_from
    my $start = $num_from > 2 ? ($num_from | 1) : 3;

    for (my $c = $start; $c <= $num_to; $c += 2) {
        push @primes, $c if $self->_is_prime($c);
    }

    return wantarray ? @primes : scalar @primes;
}

sub range_from { return $_[0]->{_range_from}; }

sub range_to { return $_[0]->{_range_to}; }

sub next {
    my $self = shift;

    # Initialize _index if not already
    if (!defined $self->{_index}) {
        my $seed = $self->{_seed} // 2;
        $seed = 2 if $seed < 2;

        # Find the first index in _bitpacked_sieve_list >= seed
        my $i = 0;
        $i++ while $i <= $#{ $self->{_bitpacked_sieve_list} } &&
                  $self->{_bitpacked_sieve_list}[$i] < $seed;

        $self->{_index} = $i - 1;  # -1 so first next() increments to correct prime
    }

    # Increment index and return prime if inside sieve
    if ($self->{_index} + 1 <= $#{ $self->{_bitpacked_sieve_list} }) {
        $self->{_seed} = $self->{_bitpacked_sieve_list}[ ++$self->{_index} ] + 1;
        return $self->{_bitpacked_sieve_list}[ $self->{_index} ];
    }

    # Beyond sieve: fall back to slow check
    my $candidate = $self->{_seed};
    $candidate = 2 if $candidate < 2;
    $candidate++ if $candidate > 2 && $candidate % 2 == 0;

    while ($candidate <= MAX_SEED) {
        if ($self->_slow_is_prime($candidate)) {
            $self->{_seed} = $candidate + 1;
            return $candidate;
        }
        $candidate += 2;
    }

    return 0;  # no higher prime
}

sub previous {
    my $self = shift;

    # Initialize _index if not already
    if (!defined $self->{_index}) {
        my $seed = $self->{_seed} // 2;
        $seed = 2 if $seed < 2;

        # Find first index in _bitpacked_sieve_list > seed
        my $i = 0;
        $i++ while $i <= $#{ $self->{_bitpacked_sieve_list} } &&
                  $self->{_bitpacked_sieve_list}[$i] <= $seed;

        $self->{_index} = $i;  # so first previous() decrements to correct prime
    }

    # Decrement index and return prime if inside sieve
    if ($self->{_index} - 1 >= 0) {
        $self->{_seed} = $self->{_bitpacked_sieve_list}[ --$self->{_index} ] - 1;
        return $self->{_bitpacked_sieve_list}[ $self->{_index} ];
    }

    # Below sieve: fall back to slow check
    my $candidate = $self->{_seed};
    $candidate-- if $candidate % 2 == 0 && $candidate > 2;

    while ($candidate > 2) {
        if ($self->_slow_is_prime($candidate)) {
            $self->{_seed} = $candidate - 1;
            return $candidate;
        }
        $candidate -= 2;
    }

    return 0;  # no lower prime
}

sub _is_prime {
    my ($self, $num) = @_;

    # Quickly reject numbers less than 2
    return 0 if $num < 2;

    # Use sieve if within the cached limit
    if ($num <= $self->{_sieve_limit} && defined $self->{_bitpacked_sieve}) {
        return vec($self->{_bitpacked_sieve}, $num, 1);
    }

    # Optional: fallback for numbers beyond sieve limit (slow check)
    return $self->_slow_is_prime($num);
}

# Example fallback slow prime check (you can keep your previous _is_prime logic here)
sub _slow_is_prime {
    my ($self, $num) = @_;
    return 0 if $num < 2;
    return 0 if $num % 2 == 0 && $num != 2;
    my $limit = int(sqrt($num));
    for (my $i = 3; $i <= $limit; $i += 2) {
        return 0 if $num % $i == 0;
    }
    return 1;
}

sub _generate_bitpacked_sieve {
    my ($self, $limit) = @_;

    # Full sieve from 2 to limit
    my $bits = "\xff" x int(($limit + 7) / 8);
    vec($bits, 0, 1) = 0;
    vec($bits, 1, 1) = 0;

    for (my $i = 2; $i * $i <= $limit; $i++) {
        if (vec($bits, $i, 1)) {
            for (my $j = $i * $i; $j <= $limit; $j += $i) {
                vec($bits, $j, 1) = 0;
            }
        }
    }

    # Populate list and index starting from requested seed/start
    my $range_start = $self->{_seed};
    $range_start = 2 if $range_start < 2;

    $self->{_bitpacked_sieve_list}     = [];

    for my $num ($range_start .. $limit) {
        if (vec($bits, $num, 1)) {
            push @{ $self->{_bitpacked_sieve_list} }, $num;
        }
    }

    return $bits;
}

1;

__END__


=head1 NAME

Vigil::Prime - High-performance prime number generator with caching and range iteration.

=head1 SYNOPSIS

    use Vigil::Prime;

    # Create a prime generator from 2 to 100_000
    my $primes = Vigil::Prime->new(2, 100_000);

    # Get the next prime from the seed
    my $p = $primes->next();

    # Get the previous prime
    my $q = $primes->previous();

    # Access a copy of the sieve list
    my @list = $primes->sieve_list();

    # Get all primes in a specific range
    my @range_primes = $primes->range(100, 200);

    # Get or set the current seed
    my $current_seed = $primes->seed();
    $primes->seed(5000);

=head1 DESCRIPTION

Vigil::Prime provides fast prime number generation using a **bitpacked sieve of Eratosthenes** for small to moderate ranges, combined with a slow primality check for larger numbers. It supports:

=over 4

=item * Iterating forwards and backwards from a seed

=item * Generating primes in an arbitrary range

=item * Caching the sieve for repeated access

=item * Optional limits with warnings and hard stops to avoid excessive memory usage

=back

This module is designed for both **programmatic use** in scripts and applications, and **interactive exploration** of prime sequences.

=head1 CLASS METHODS

=head2 new($start, $end, {ignore_limits => 1})

This constructor creates a new `Vigil::Prime` object.

    my $prime = Vigil::Prime->new($start, $end);
	
    my $primt = Vigil::Prime->new($start, $end, {ignore_limits => 1});

=over 4

=item $start

Starting seed (default 2)

=item $end

Upper limit for sieve (default 100_000)

=item ignore_limits

If true, disables warning and hard limit checks

=back

Throws an exception if invalid ranges are supplied, negative seeds, or values exceeding the 64-bit integer limit.

=head1 OBJECT METHODS

=over 4

=item C<my $value = $obj-E<gt>next;>

Returns the next prime greater than or equal to the current seed. Updates the seed internally. Returns 0 if no higher prime exists.

=item C<my $value = $obj-E<gt>previous;>

Returns the previous prime less than or equal to the current seed. Updates the seed internally. Returns 0 if no lower prime exists.

=item C<my @sieve_list = $obj-E<gt>sieve_list;>

Returns a copy of the internally cached sieve as an array of primes.

=item C<my @range = $obj-E<gt>range($from, $to);>

Returns all primes between $from and $to (inclusive). Uses the cached sieve when possible, falls back to slow primality checks otherwise. Returns an array in list context or a count in scalar context.

=item C<$obj-E<gt>range_from;>

Returns the low value used to calculate the last call to C<range()>.

=item C<$obj-E<gt>range_to;>

Returns the high value used to calculate the last call to C<range()>.

=item C<$obj-E<gt>seed($value)> or C<my $current_seed = $obj-E<gt>seed;>

Get or set the current seed. Setting a new value updates the internal pointer for next/previous. Values are capped to the maximum allowed integer and floored at 0.

=back

=head1 WARNINGS / LIMITS

=over 4

=item * Large ranges may consume substantial memory (~8 bytes per number in sieve). 

=item * Default hard limit for the sieve is 10_000_000_000 numbers. 

=item * Use C<ignore_limits =E<gt> 1> only if you understand the memory/time implications.

=back

=head2 Local Installation

If your host does not allow you to install from CPAN, then you can install this module locally two ways:

=over 4

=item * Same Directory

In the same directory as your script, create a subdirectory called "Vigil". Then add these two lines, in this order, to your script:

	use lib '.';           # Add current directory to @INC
	use Vigil::Prime;      # Now Perl can find the module in the same dir
	
	#Then call it as normal:
	my $prime = Vigil::Prime->new;

=item * In a different directory

First, create a subdirectory called "Vigil" then add it to C<@INC> array through a C<BEGIN{}> block in your script:

	#!/usr/bin/perl
	BEGIN {
		push(@INC, '/path/on/server/to/Vigil');
	}

	#Then call it as normal:
	my $prime = Vigil::Prime->new;

=back

=head1 AUTHOR

Jim Melanson (jmelanson1965@gmail.com).

Created July, 2016.

Last Updated August, 2025.

License: Use it as you will, and don't pretend you wrote it - be a mensch.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
