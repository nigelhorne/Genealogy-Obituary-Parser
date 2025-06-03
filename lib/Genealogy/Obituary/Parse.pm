package Genealogy::Obituary::Parse;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(parse_obituary);
our $VERSION   = '0.01';

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
    my ($text) = @_;
    my %rel;

	if ($text =~ /(?:survived by|leaves behind).*?(?:wife|husband|spouse)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)/i) {
    
        push @{ $rel{spouse} }, $1;
    }

    if ($text =~ /(?:sons|daughters|children)\s+([A-Z][a-z]+(?:\s+and\s+[A-Z][a-z]+)*)/i) {
        my @kids = split /\s+and\s+/, $1;
        push @{ $rel{children} }, @kids;
    }

    if ($text =~ /grandchildren\s+([A-Z][a-z]+(?:\s+and\s+[A-Z][a-z]+)*)/i) {
        my @grands = split /\s+and\s+/, $1;
        push @{ $rel{grandchildren} }, @grands;
    }

    return \%rel;
}

=head1 AUTHOR

Nigel Horne

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
