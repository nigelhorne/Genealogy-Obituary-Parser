use strict;
use warnings;
use Test::Most;

# Test of files that should return empty data

use Genealogy::Obituary::Parser qw(parse_obituary);

for my $dir (qw(t/corpus/empty)) {
	for my $file (glob("$dir/*.txt")) {
		open my $fh, '<', $file or die "Can't open $file: $!";
		local $/ = undef;
		my $text = <$fh>;

		ok(!defined parse_obituary($text), "$file: no false positives");
	}
}

done_testing();
