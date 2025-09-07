# NAME

Vigil::Prime - High-performance prime number generator with caching and range iteration.

# SYNOPSIS

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

# DESCRIPTION

Vigil::Prime provides fast prime number generation using a \*\*bitpacked sieve of Eratosthenes\*\* for small to moderate ranges, combined with a slow primality check for larger numbers. It supports:

- Iterating forwards and backwards from a seed
- Generating primes in an arbitrary range
- Caching the sieve for repeated access
- Optional limits with warnings and hard stops to avoid excessive memory usage

This module is designed for both \*\*programmatic use\*\* in scripts and applications, and \*\*interactive exploration\*\* of prime sequences.

# CLASS METHODS

## new($start, $end, {ignore\_limits => 1})

This constructor creates a new \`Vigil::Prime\` object.

    my $prime = Vigil::Prime->new($start, $end);
        
    my $primt = Vigil::Prime->new($start, $end, {ignore_limits => 1});

- $start

    Starting seed (default 2)

- $end

    Upper limit for sieve (default 100\_000)

- ignore\_limits

    If true, disables warning and hard limit checks

Throws an exception if invalid ranges are supplied, negative seeds, or values exceeding the 64-bit integer limit.

# OBJECT METHODS

- `my $value = $obj->next;`

    Returns the next prime greater than or equal to the current seed. Updates the seed internally. Returns 0 if no higher prime exists.

- `my $value = $obj->previous;`

    Returns the previous prime less than or equal to the current seed. Updates the seed internally. Returns 0 if no lower prime exists.

- `my @sieve_list = $obj->sieve_list;`

    Returns a copy of the internally cached sieve as an array of primes.

- `my @range = $obj->range($from, $to);`

    Returns all primes between $from and $to (inclusive). Uses the cached sieve when possible, falls back to slow primality checks otherwise. Returns an array in list context or a count in scalar context.

- `$obj->range_from;`

    Returns the low value used to calculate the last call to `range()`.

- `$obj->range_to;`

    Returns the high value used to calculate the last call to `range()`.

- `$obj->seed($value)` or `my $current_seed = $obj->seed;`

    Get or set the current seed. Setting a new value updates the internal pointer for next/previous. Values are capped to the maximum allowed integer and floored at 0.

# WARNINGS / LIMITS

- Large ranges may consume substantial memory (~8 bytes per number in sieve). 
- Default hard limit for the sieve is 10\_000\_000\_000 numbers. 
- Use `ignore_limits => 1` only if you understand the memory/time implications.

## Local Installation

If your host does not allow you to install from CPAN, then you can install this module locally two ways:

- Same Directory

    In the same directory as your script, create a subdirectory called "Vigil". Then add these two lines, in this order, to your script:

            use lib '.';           # Add current directory to @INC
            use Vigil::Prime;      # Now Perl can find the module in the same dir
            
            #Then call it as normal:
            my $prime = Vigil::Prime->new;

- In a different directory

    First, create a subdirectory called "Vigil" then add it to `@INC` array through a `BEGIN{}` block in your script:

            #!/usr/bin/perl
            BEGIN {
                    push(@INC, '/path/on/server/to/Vigil');
            }

            #Then call it as normal:
            my $prime = Vigil::Prime->new;

# AUTHOR

Jim Melanson (jmelanson1965@gmail.com).

Created July, 2016.

Last Updated August, 2025.

License: Use it as you will, and don't pretend you wrote it - be a mensch.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
