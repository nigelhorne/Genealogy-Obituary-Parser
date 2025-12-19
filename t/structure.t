use strict;
use warnings;
use Test::Most;

# Ensure that the structure of the output files looks sensible

use Genealogy::Obituary::Parser qw(parse_obituary);
use lib 't/lib';
use Test::ObituaryStructure;

for my $file (glob("t/corpus/valid/*.txt")) {
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	my $text = <$fh>;

	my $data;
	lives_ok {
		$data = parse_obituary($text);
	} "Parse $file";

	next unless $data;

	validate_family_structure($data, $file);
}

done_testing();
