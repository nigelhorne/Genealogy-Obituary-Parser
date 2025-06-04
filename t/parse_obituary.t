use strict;
use warnings;
use Test::Most;
use Genealogy::Obituary::Parse qw(parse_obituary);

my $text = <<'END';
He is survived by his wife Mary, sons John and David, and grandchildren Sophie, Liam, and Ava.
His parents were George and Helen.
He also leaves behind his sister Claire.
END

my $rel = parse_obituary($text);

# diag(Data::Dumper->new([$rel])->Dump());

cmp_deeply($rel,
	{
		'spouse' => [
			{ 'name' => 'Mary' }
		], 'parents' => [
			{ 'name' => 'George' }, 
			{ 'name' => 'Helen' }
		], 'children' => [
			{ 'name' => 'John' }, 
			{ 'name' => 'David' }
		], 'grandchildren' => [
			{ 'name' => 'Sophie' }, 
			{ 'name' => 'Liam' },
			{ 'name' => 'Ava' }
		], 'siblings' => [
			{ 'name' => 'Claire' }, 
		]
	}
);

done_testing();
