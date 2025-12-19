use strict;
use warnings;
use Test::Most;

use Genealogy::Obituary::Parser qw(parse_obituary);

my %EXPECTED = (
	children => 'ARRAY',
	grandchildren => 'ARRAY',
	spouse => 'ARRAY',
	siblings => 'ARRAY',
	brothers => 'ARRAY',
	sisters => 'ARRAY',
	parents => 'HASH',
	birth => 'HASH',
	death => 'HASH',
	funeral => 'HASH',
);

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

		for my $key (keys %EXPECTED) {
			next unless exists $data->{$key};
			is(
				ref($data->{$key}),
				$EXPECTED{$key},
				"$file: $key has correct type"
			);
		}
		my $second = parse_obituary($text);

		is_deeply($second, $data, "$file: parsing is idempotent");
	}
}

done_testing();
