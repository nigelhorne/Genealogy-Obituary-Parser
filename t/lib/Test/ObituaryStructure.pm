package Test::ObituaryStructure;

use strict;
use warnings;
use Exporter 'import';
use Test::More;

our @EXPORT = qw(validate_family_structure);

sub validate_family_structure {
	my ($family, $label) = @_;

	ok(ref $family eq 'HASH', "$label: family is hashref");

	for my $key (keys %$family) {
		my $val = $family->{$key};

		ok(
			!ref($val) || ref($val) =~ /^(ARRAY|HASH)$/,
			"$label: $key is scalar, array, or hash"
		);

		if (ref $val eq 'ARRAY') {
			for my $item (@$val) {
				ok(
					ref($item) eq 'HASH' || !ref($item),
					"$label: $key entries are hashrefs or scalars"
				);

				if (ref $item eq 'HASH') {
					ok(
						exists $item->{name},
						"$label: $key entry has name"
					);
				}
			}
		}

		if (ref $val eq 'HASH') {
			ok(
				!exists($val->{name}) || defined($val->{name}),
				"$label: $key hash has defined name if present"
			);
		}
	}
}

1;
