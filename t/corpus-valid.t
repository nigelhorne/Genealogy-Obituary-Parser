use strict;
use warnings;
use Test::Most;

use Genealogy::Obituary::Parser qw(parse_obituary);

for my $dir (qw(t/corpus/valid t/corpus/edge)) {
	for my $file (glob("$dir/*.txt")) {
		open my $fh, '<', $file or die "Can't open $file: $!";
		local $/ = undef;
		my $text = <$fh>;

		my $data;

		lives_ok {
			$data = parse_obituary($text);
		} "Parser survives $file";

		ok(ref $data eq 'HASH', "Parser returns hash for $file");

		ok(exists $data->{sisters} || exists $data->{brothers}, "people key exists for $file");
	}
}

done_testing;

