use strict;
use warnings;

use Data::Dumper;
use Test::Most;
use Genealogy::Obituary::Parse qw(parse_obituary);

my $text = 'She is survived by her husband Paul, daughters Anna and Lucy, and grandchildren Jake and Emma.';

my $rel = parse_obituary($text);

# diag(Data::Dumper->new([$rel])->Dump());

ok(defined $rel->{spouse}, 'Spouse field is defined');
diag explain $rel unless defined $rel->{spouse};

cmp_deeply($rel,
	{
		'spouse' => [
			{ 'name' => 'Paul' }
		], 'children' => [
			{ 'name' => 'Anna' }, 
			{ 'name' => 'Lucy' }
		], 'grandchildren' => [
			{ 'name' => 'Jake' }, 
			{ 'name' => 'Emma' }
		]
	}
);

done_testing();
