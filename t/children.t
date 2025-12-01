use strict;
use warnings;
use Test::More tests => 1;

use Genealogy::Obituary::Parser qw(parse_obituary);

my $text = 'She is survived by her children Anna, Lucy and Tom.';

my $data = parse_obituary($text);

# Extract just the names
my @names = map { $_->{name} } @{ $data->{children} };

is_deeply(
	\@names,
	[ 'Anna', 'Lucy', 'Tom' ],
	'Correctly parses multiple children with commas and "and"'
);
