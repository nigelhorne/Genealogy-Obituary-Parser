use strict;
use warnings;
use Test::Most;

use Genealogy::Obituary::Parser qw(parse_obituary);
my @mutators = (
	[ 'remove commas', sub { $_[0] =~ s/,//gr } ],
	[ 'and to semicolon', sub { $_[0] =~ s/\band\b/;/gr } ],
	[ 'append clause', sub { $_[0] . " – survived by many." } ],
	[ 'numbers to words', sub { $_[0] =~ s/\d+/two/gr } ],
);


for my $file (glob("t/corpus/valid/*.txt")) {
	open my $fh, '<', $file or die "Can't open $file: $!";
	local $/ = undef;
	my $text = <$fh>;

	for my $m (@mutators) {
		my ($label, $mut) = @{$m};
		my $mutated = $mut->($text);
		my $data;

		lives_ok {
			$data = parse_obituary($mutated);
		} "Fuzzer survives mutation of $file";

		ok(!defined($data) || (ref($data) eq 'HASH'), "Fuzzer survices ($label) of $file");
	}
}

done_testing();
