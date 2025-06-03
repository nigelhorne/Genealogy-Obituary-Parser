package Genealogy::Obituary::Parse;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(parse_obituary);
our $VERSION	= '0.01';

=head1 NAME

Genealogy::Obituary::Parse - Extract structured family relationships from obituary text

=head1 SYNOPSIS

  use Genealogy::Obituary::Parse qw(parse_obituary);

  my $text = "She is survived by her husband Paul, daughters Anna and Lucy, and grandchildren Jake and Emma.";
  my $data = parse_obituary($text);

  # $data = {
  #   spouse       => ['Paul'],
  #   children     => ['Anna', 'Lucy'],
  #   grandchildren => ['Jake', 'Emma'],
  # };

=head1 DESCRIPTION

This module parses freeform obituary text and extracts structured family relationship data
for use in genealogical applications.

=head1 FUNCTIONS

=head2 parse_obituary($text)

Returns a hashref of extracted relatives.

=cut

sub parse_obituary {
	my $text = shift;
	my %data;

	my @patterns = (
		[ qr/\bdaughters?\s+([^.,;]+)/i,      'children' ],
		[ qr/\bsons?\s+([^.,;]+)/i,           'children' ],
		[ qr/\bchildren\s+([^.,;]+)/i,        'children' ],
		[ qr/\bgrandchildren\s+([^.]+)/i,   'grandchildren' ],
		[ qr/\bwife\s+([^.,;]+)/i,            'spouse' ],
		[ qr/\bhusband\s+([^.,;]+)/i,         'spouse' ],
		[ qr/\bhis parents were\s+([^.,;]+)/i,'parents' ],
		[ qr/\bhis father was\s+([^.,;]+)/i,  'parents' ],
		[ qr/\bhis mother was\s+([^.,;]+)/i,  'parents' ],
		[ qr/\bsister(?:s)?\s+([^.,;]+)/i,    'siblings' ],
		[ qr/\bbrother(?:s)?\s+([^.,;]+)/i,   'siblings' ],
		[ qr/\bsiblings\s+([^.,;]+)/i,        'siblings' ],
	);

	for my $p (@patterns) {
		my ($re, $field) = @$p;
		while ($text =~ /$re/g) {
			my $list = $1 // '';
			next unless $list;

			# Robust splitting on commas and "and"
			my @names = grep { length } map { s/^\s+|\s+$//gr } split /\s*(?:,|(?:\band\b))\s*/i, $list;
			push @{ $data{$field} }, @names;
		}
	}

	return \%data;
}

=head1 AUTHOR

Nigel Horne

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
