#!/usr/bin/env perl
use strict;
use warnings;
#use FindBin;
#use lib "$FindBin::Bin/../lib";
use Test::More;

use Vigil::Prime;

# Create a prime generator from 2 to 100_000
my $primes = Vigil::Prime->new(2, 100_000);
ok($primes, 'Object constructor okay');

{
    local $SIG{__WARN__} = sub { };
	
	my @ranges = $primes->range(7, 7);
	ok($ranges[0] == 7 && scalar @ranges == 1, 'range(7,7) working');
	@ranges = ();
	
	@ranges = $primes->range(9, 9);
	is($ranges[0], undef, 'range(9,9) working');
	@ranges = ();
	
	@ranges = $primes->range(200, 100);
	ok(scalar @ranges > 1, 'range() reversal working');
}

ok($primes->seed(5000), 'seed() working');

my $p_next = $primes->next();
ok(defined $p_next && $p_next > 5000, 'next() working');

my $p_prev = $primes->previous();
ok(defined $p_prev && $p_prev > 0 && $p_prev < 5000, 'previous() working');

my @list = $primes->sieve_list();
ok(scalar @list > 0, 'sieve_list() working');

my @range_primes = $primes->range(100, 200);
ok(scalar @range_primes > 0, 'range() working');

done_testing();
