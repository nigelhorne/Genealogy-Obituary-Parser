package Genealogy::Obituary::Parser;

use strict;
use warnings;

use DateTime::Format::Text;
use Exporter 'import';
use Geo::Coder::Free;
use Geo::Coder::List;
use Params::Get 0.13;
use Return::Set 0.02;
use Params::Validate::Strict;

our @EXPORT_OK = qw(parse_obituary);
our $geocoder;

# TODO:	use Lingua::EN::Tagger;
# TODO:	add more general code, e.g. where it looks for father, also look for mother
# TODO: parse https://funeral-notices.co.uk/notice/adams/5244000

=head1 NAME

Genealogy::Obituary::Parser - Extract structured family relationships from obituary text

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

  use Genealogy::Obituary::Parse qw(parse_obituary);

  my $text = 'She is survived by her husband Paul, daughters Anna and Lucy, and grandchildren Jake and Emma.';
  my $data = parse_obituary($text);

  # $data = {
  #   spouse   => ['Paul'],
  #   children => ['Anna', 'Lucy'],
  #   grandchildren => ['Jake', 'Emma'],
  # };

=head1 DESCRIPTION

This module parses freeform obituary text and extracts structured family relationship data
for use in genealogical applications.
It parses obituary text and extract structured family relationship data, including details about children, parents, spouse, siblings, grandchildren, and other relatives.

=head1 FUNCTIONS

=head2 parse_obituary($text)

The routine processes the obituary content to identify and organize relevant family information into a clear, structured hash.
It returns a hash reference containing structured family information,
with each family member's data organized into distinct categories such as children, spouse, parents, siblings, etc.

Takes a string, or a ref to a string.

=head3 API SPECIFICATION

=head4 INPUT

  {
    'text' => {
      'type' => 'string',	# or stringref
      'min' => 1,
      'max' => 5000
    }
  }

=head4 OUTPUT

=over 4

=item * No matches: undef

=back

  {
    type => 'hashref',
    'min' => 1,
    'max' => 10
  }

=cut

sub parse_obituary
{
        my $params = Params::Validate::Strict::validate_strict({
		args => Params::Get::get_params('text', \@_),
		schema => {
			'text' => {
				'type' => 'string',
				'min' => 1,
				'max' => 5000
			}
		}
	});
	my $text = $params->{'text'};

	if(ref($text) eq 'SCALAR') {
		$text = ${$text};
	}

	# Quick scan to get started
	sub parse_obituary_quick {
		my $text = shift;
		my %data;

		my @patterns = (
			[ qr/\bdaughters?\s+([^.,;]+)/i,  'children' ],
			[ qr/\bsons?\s+([^.,;]+)/i, 'children' ],
			[ qr/\bchildren\s+([^.,;]+)/i, 'children' ],
			[ qr/\bgrandchildren\s+([^.;]+)/i, 'grandchildren' ],
			[ qr/\bwife\s+([^.,;]+)/i, 'spouse' ],
			[ qr/\bhusband\s+([^.,;]+)/i, 'spouse' ],
			[ qr/\bhis parents were\s+([^.,;]+)/i,'parents' ],
			[ qr/\bhis father was\s+([^.,;]+)/i, 'parents' ],
			[ qr/\bhis mother was\s+([^.,;]+)/i, 'parents' ],
			[ qr/\bsister(?:s)?\s+([^.,;]+)/i, 'siblings' ],
			[ qr/\bbrother(?:s)?\s+([^.,;]+)/i, 'siblings' ],
			[ qr/\bsiblings\s+([^.,;]+)/i, 'siblings' ],
		);

		for my $p (@patterns) {
			my ($re, $field) = @$p;
			while ($text =~ /$re/g) {
				my $list = $1;
				next unless $list;

				# Robust splitting on commas and "and"
				my @names = grep { length } map { s/^\s+|\s+$//gr } split /\s*(?:,|(?:\band\b))\s*/i, $list;
				push @{$data{$field}}, map { { 'name' => $_ } } @names;
			}
		}

		return \%data;
	}

	# my %family = %{parse_obituary_quick($text)};
	my %family;

	# Helper to extract people from a specific section and remove empty entries
	sub extract_people_section {
		my $section = shift;
		return unless $section;

		$section =~ s/\s+and\s+/, /g;	# Ensure "and" is treated as a separator
		$section =~ s/([A-Za-z]+),\s+([A-Z]{2})/$1<<COMMA>>$2/g;
		my @entries = split /\s*,\s*/, $section;

		my @people;
		foreach my $entry (@entries) {
			$entry =~ s/<<COMMA>>/, /g;

			my ($name, $spouse, $location) = ('', '', '');

			# Match "Ian (Terry) Girvan of Surrey, BC"
			if ($entry =~ /^(\w+)\s+\(([^)]+)\)\s+(\w+)\s+of\s+(.+)$/) {
				$name = "$1 $3"; $spouse = $2; $location = $4;
			}
			# Match "Gwen Steeves (Leslie) of Riverview, NB"
			elsif ($entry =~ /^(.+?)\s+\(([^)]+)\)\s+of\s+(.+)$/) {
				$name = $1; $spouse = $2; $location = $3;
			}
			# Match "Carol Girvan of Dartmouth, NS"
			elsif ($entry =~ /^(.+?)\s+of\s+(.+)$/) {
				$name = $1; $location = $2;
			} else {
				# Match names only (e.g. for siblings)
				$name = $entry;
			}

			next if !$name;	# Skip if name is empty
			next if($name =~ /^father-in-law\sto\s/);	# Skip follow ons
			last if($name =~ /^devoted\s/i);
			last if($name =~ /^loved\s/i);

			# Create a hash and filter out blank fields
			my %person = (
				name	 => $name,
				spouse => $spouse,
				location => $location,
			);

			# Remove blank fields
			%person = map { $_ => $person{$_} } grep { defined $person{$_} && $person{$_} ne '' } keys %person;

			push @people, \%person;
		}
		return \@people;
	}

	sub extract_names_from_phrase {
		my $phrase = shift;
		my @names;

		$phrase =~ s/[.;]//g;

		# Case: "Christopher, Thomas, and Marsha Cloud"
		if ($phrase =~ /^((?:\w+\s*,\s*)+\w+),?\s*and\s+(\w+)\s+(\w+)$/) {
			my ($pre, $last_first, $last) = ($1, $2, $3);
			my @firsts = split(/\s*,\s*/, $pre);
			push @firsts, $last_first;
			push @names, map { "$_ $last" } @firsts;
			return @names;
		}

		# Case: "Christopher and Thomas Cloud"
		if ($phrase =~ /^([\w\s]+?)\s+and\s+(\w+)\s+(\w+)$/) {
			my ($first_part, $second_first, $last) = ($1, $2, $3);
			my @firsts = split(/\s*,\s*|\s+and\s+/, $first_part);
			push @names, map { "$_ $last" } (@firsts, $second_first);
			return @names;
		}

		# Fallback: Split by comma or 'and'
		$phrase =~ s/, and grandchildren.+//;	# Handle "Anna and Lucy, and grandchildren Jake and Emma"
		my @parts = split /\s*(?:,|and)\s*/, $phrase;
		push @names, grep { defined($_) && $_ ne '' } @parts;
		return @names;
	}

	# Correct extraction of children (skipping "his/her")
	if ($text =~ /survived by (his|her) children\s*([^\.;]+)/i) {
		my $children_text = $2;
		$family{children} = extract_people_section($children_text);
	} elsif ($text =~ /Loving mum to\s*([^\.;]+)/i) {	# Look for the phrase "Loving mum to"
		my $children_text = $1;
		$family{children} = extract_people_section($children_text);
	} elsif ($text =~ /Loving father of\s*([^\.;]+)/i) {	# Look for the phrase "Loving father of"
		my $children_text = $1;
		$family{children} = extract_people_section($children_text);
	} elsif($text =~ /mother of\s*([^\.;]+)?,/i) {	# Look for the phrase "mother of"
		my $children_text = $1;
		$children_text =~ s/, grandmother.+//;
		$family{children} = extract_people_section($children_text);
	} elsif($text =~ /sons,?\s*([a-z]+)\s+and\s+([a-z]+)/i) {
		my @children;
		my @grandchildren;

		push @children, { name => $1, sex => 'M' }, { name => $2, sex => 'M' };
		if($text =~ /\bdaughter,?\s([a-z]+)/i) {
			push @children, { 'name' => $1, 'sex' => 'F' }
		}
		if($text =~ /\bgranddaughter,?\s([a-z]+)/i) {
			push @grandchildren, { 'name' => $1, 'sex' => 'F' };
		}
		$family{children} = \@children if @children;
		$family{grandchildren} = \@grandchildren if @grandchildren;
	} else {
		my @children;

		# my $tagger = Lingua::EN::Tagger->new(longest_noun_phrase => 0);
		# my $tagged = $tagger->add_tags($text);

		if($text =~ /\ssons,\s*(.*?);/s) {
			my $sons_text = $1;
			if($sons_text =~ /, all of (.+)$/) {
				my $location = $1;
				while($sons_text =~ /([\w. ]+?),\s/g) {
					my $son = $1;
					if($son =~ /(\w+)\s+and\s+(\w+)/) {
						push @children, {
							name => $1,
							location => $location,
							sex => 'M',
						}, {
							name => $2,
							location => $location,
							sex => 'M',
						};
						last;
					} else {
						push @children, {
							name => $son,
							location => $location,
							sex => 'M',
						};
					}
				}
			} else {
				while($sons_text =~ /([\w. ]+?),\s*([\w. ]+?)(?:\s+and|\z)/g) {
					push @children, {
						name => $1,
						location => $2,
						sex => 'M',
					};
				}
			}
		}
		if($text =~ /\sdaughters?,\s*Mrs\.\s+(.+?)\s+(\w+),\s+([^;]+)\sand/) {
			push @children, {
				name => $1,
				location => $3,
				sex => 'F',
				spouse => { 'name' => $2, sex => 'M' }
			};
		} elsif($text =~ /one daughter,\s*(.+?),\s*(.+?);/) {
			my $name = $1;
			my $location = $2;
			if($name =~ /(\w+)\s+(\w+)/) {
				push @children, {
					name => $1,
					location => $location,
					sex => 'F',
					spouse => { name => $2, sex => 'M' }
				};
			} else {
				push @children, {
					name => $1,
					location => $location,
					sex => 'F',
				};
			}
		}
		$family{children} = \@children if @children;

		if(!$family{'children'}) {
			while($text =~ /\b(son|daughter)s?,\s*([A-Z][a-z]+(?:\s+\([A-Z][a-z]+\))?)\s*(?:and their children ([^.;]+))?/g) {
				my $sex = $1 eq 'son' ? 'M' : 'F';
				my $child = $2;
				my $grandkids = $3;
				if(my @grandchildren = $grandkids ? split /\s*,\s*|\s+and\s+/, $grandkids : ()) {
					push @children, {
						name => $child,
						sex => $sex,
						grandchildren => \@grandchildren,
					};
				} elsif(($sex eq 'F') && ($child =~ /(.+)\s+\((.+)\)/)) {
					push @children, { name => $1, sex => 'F', spouse => { name => $2, sex => 'M' } }
				} elsif($child ne 'Mrs') {
					push @children, { name => $child, sex => $sex }
				}
			}
		}
		$family{children} = \@children if @children;
	}

	if(!$family{'children'}) {
		if($text =~ /\ssons?[,\s]\s*(.+?)[;\.]/) {
			my $raw = $1;
			$raw =~ s/\sand their .+//;
			my @children = extract_names_from_phrase($raw);
			push @{$family{children}}, map { { name => $_, sex => 'M' } } @children;
		}
		if($text =~ /\sdaughters?[,\s]\s*(.+?)[;\.]/) {
			my $raw = $1;
			$raw =~ s/\sand their .+//;
			my @children = extract_names_from_phrase($raw);
			push @{$family{children}}, map { { name => $_, sex => 'F' } } @children;
		}
	}

	# Extract grandchildren
	if(!$family{'grandchildren'}) {
		if($text =~ /grandchildren\s+([^\.;]+)/i) {
			my @grandchildren = split /\s*(?:,|and)\s*/i, $1;
			if(scalar(@grandchildren)) {
				$family{'grandchildren'} = [ map { { 'name' => $_ } } grep { defined $_ && $_ ne '' } @grandchildren ];
			}
		}
	}
	if($family{'grandchildren'} && scalar @{$family{grandchildren}}) {
		while((exists $family{'grandchildren'}->[0]) && (length($family{'grandchildren'}->[0]) == 0)) {
			shift @{$family{'grandchildren'}};
		}
		if($family{'grandchildren'}->[0] =~ /brothers/) {
			if(!exists $family{'brothers'}) {
				shift @{$family{'grandchildren'}};
				$family{'brothers'} = extract_people_section(join(', ', @{$family{'grandchildren'}}));
			}
			delete $family{grandchildren};
		}
	} else {
		delete $family{grandchildren};
	}
	if((!defined($family{'grandchildren'})) || (($#{$family{'grandchildren'}}) <= 0)) {
		# handle devoted Grandma to Tom, Dick, and Harry and loved Mother-in-law to Jack and Jill"
		my ($grandchildren_str) = $text =~ /Grandma to (.*?)(?: and loved|$)/;
		# Normalize and split into individual names
		my @grandchildren;
		if($grandchildren_str) {
			@grandchildren = split /,\s*|\s+and\s+/, $grandchildren_str;
		}
		if(scalar(@grandchildren)) {
			$family{'grandchildren'} = \@grandchildren;
		} elsif($text =~ /grandm\w+\s/) {
			my $t = $text;
			$t =~ s/.+(grandm\w+\s+.+?\sand\s[\w\.;,]+).+/$1/;
			$family{grandchildren} = [ split /\s*(?:,|and)\s*/i, ($t =~ /grandm\w+\sto\s+([^\.;]+)/i)[0] || '' ];
		}
	}

	# Extract siblings (sisters and brothers) correctly, skipping "her" or "his"
	if($text =~ /predeceased by (his|her) sisters?\s*([^;\.]+);?/i) {
		my $sisters_text = $2;
		$sisters_text =~ s/^,\s+//;
		$family{sisters} = extract_people_section($sisters_text);
	} else {
		while($text =~ /\bsister[,\s]\s*([A-Z][a-z]+(?:\s+[A-Z][a-z.]+)*)(?:,\s*([A-Z][a-z]+))?/g) {
			my $name = $1;
			$family{'sisters'} ||= [];
			if($name eq 'Mrs') {
				if($text =~ / sister,\s*Mrs\.\s+([A-Z][a-zA-Z]+\s+[A-Z][a-zA-Z]+)/) {
					$name = $1;
				} else {
					undef $name;
				}
			}
			if($name) {
				push @{$family{sisters}}, {
					name => $name,
					status => ($text =~ /\bpredeceased by.*?$name/i) ? 'deceased' : 'living',
				};
			}
		}

		if(!exists($family{'sisters'})) {
			if($text =~ /\stwo\ssisters,\s*(.*?)\sand\s(.*?)[;:]/s) {
				my($first, $second) = ($1, $2);
				foreach my $sister($first, $second) {
					if($sister =~ /Mrs\.\s(.+?),\s(.+)/) {
						my $name = $1;
						my $location = $2;
						if($name =~ /(\w+)\s+(\w+)/) {
							push @{$family{sisters}}, {
								name => $1,
								location => $location,
								sex => 'F',
								spouse => { 'name' => $2, 'sex' => 'M' }
							};
						} else {
							push @{$family{sisters}}, {
								name => $name,
								location => $location,
								sex => 'F',
							};
						}
					} else {
						push @{$family{sisters}}, {
							name => $sister,
							sex => 'F',
						};
					}
				}
			}
		}
	}

	if($text =~ /predeceased by (his|her) brothers?\s*([^;\.]+);?/i) {
		my $brothers_text = $2;
		$brothers_text =~ s/^,\s+//;
		$family{brothers} = extract_people_section($brothers_text);
		# TODO: mark all statuses to deceased
	} else {
		my @siblings;

		while ($text =~ /\bbrother,\s*([A-Z][a-z]+(?:\s+[A-Z][a-z.]+)*)(?:,\s*([A-Z][a-z]+))?/g) {
			$family{'brothers'} ||= [];
			push @{$family{brothers}}, {
				name => $1,
				status => ($text =~ /\bpredeceased by.*?$1/i) ? 'deceased' : 'living',
			};
		}
		if((!$family{'brothers'}) && (!$family{'sisters'}) && (!$family{'siblings'})) {
			if($text =~ /sister of ([a-z]+) and ([a-z]+)/i) {
				push @{$family{'siblings'}},
					{ 'name' => $1 },
					{ 'name' => $2 }
			}
		}

		if(!exists($family{'brothers'})) {
			if($text =~ /\sbrothers,\s*(.*?)[;\.]/s) {
				my $brothers_text = $1;
				if($brothers_text =~ /, all of (.+)$/) {
					my $location = $1;
					while($brothers_text =~ /([\w. ]+?),\s/g) {
						my $son = $1;
						if($son =~ /(\w+)\s+and\s+(\w+)/) {
							push @{$family{brothers}}, {
								name => $1,
								location => $location,
								sex => 'M',
							}, {
								name => $2,
								location => $location,
								sex => 'M',
							};
							last;
						} else {
							push @{$family{brothers}}, {
								name => $son,
								location => $location,
								sex => 'M',
							};
						}
					}
				} else {
					while($brothers_text =~ /([\w. ]+?),\s*([\w. ]+?)(?:\s+and|\z)/g) {
						push @{$family{brothers}}, {
							name => $1,
							location => $2,
							sex => 'M',
						};
					}
				}
			}
		}
	}

	# Detect nieces/nephews
	$family{nieces_nephews} = ($text =~ /as well as several nieces and nephews/i) ? ['several nieces and nephews'] : [];

	# Extract parents and clean the names by removing unnecessary details
	if($text =~ /(son|daughter) of the late\s+(.+?)\s+and\s+(.+?)\./i) {
		my $father = $2;
		my $mother = $3;

		# Remove anything after the first comma in each parent's name
		$father =~ s/,.*//;
		$mother =~ s/,.*//;

		if($mother =~ /(.+)\s+\((.+)\)\s+(.+)/) {
			$mother = "$1 $2";
		}
		$family{parents} = {
			father => { name => $father },
			mother => { name => $mother },
		};
	} elsif($text =~ /parents were (\w+) and (\w+)/i) {
		$family{parents} = {
			father => { name => $1 },
			mother => { name => $2 },
		};
	}

	# Extract spouse's death year and remove the "(year)" from the name
	if($text =~ /(wife|husband) of the late\s+([\w\s]+)\s+\((\d{4})\)/) {
		my $name = $2;
		my $death_year = $3;

		$family{'spouse'} ||= [];

		# Remove the death year part from the spouse's name
		$name =~ s/\s*\(\d{4}\)//;

		push @{$family{'spouse'}}, {
			name => $name,
			death_year => $death_year
		}
	} elsif($text =~ /\bmarried ([^,]+),.*?\b(?:on\s+)?([A-Z][a-z]+ \d{1,2}, \d{4})(?:.*?\b(?:at|in)\s+([^.,]+))?/i) {
		$family{'spouse'} ||= [];

		push @{$family{'spouse'}}, {
			name => $1,
			married => {
				date => $2,
				place => $3 // '',
			}
		};
	} elsif($text =~ /husband (?:to|of) the late\s([\w\s]+)[\s\.]/i) {
		$family{'spouse'} ||= [];

		push @{$family{'spouse'}}, { name => $1, status => 'deceased' }
	} elsif($text =~ /\b(?:wife|husband) of ([^.,;]+)/i) {
		$family{'spouse'} ||= [];

		push @{$family{'spouse'}}, { name => $1 }
	} elsif($text =~ /\bsurvived by her husband ([^.,;]+)/i) {
		push @{$family{'spouse'}}, { name => $1, 'status' => 'living', 'sex' => 'M' }
	} elsif($text =~ /\bsurvived by his wife[,\s]+([^.,;]+)/i) {
		push @{$family{'spouse'}}, { name => $1, 'status' => 'living', 'sex' => 'F' }
	}

	# Ensure spouse location is properly handled
	if(exists $family{spouse} && (ref $family{'spouse'} eq 'HASH') && defined $family{spouse}[0]{location} && $family{spouse}[0]{location} eq 'the late') {
		delete $family{spouse}[0]{location};
	}

	# Extract the funeral information
	if($text =~ /funeral service.*?at\s+(.+?),?\s+on\s+(.*?),?\s+at\s+(.+?)\./) {
		$family{funeral} = {
			location => $1,
			date	 => $2,
			time	 => $3,
		};
	} elsif($text =~ /funeral service.*?at\s+([^\n]+?)\s+on\s+([^\n]+)\s+at\s+([^\n]+)/i) {
		$family{funeral} = {
			location => $1,
			date	 => $2,
			time	 => $3,
		};
		if($family{'funeral'}->{'date'} =~ /(.+?)\.\s{2,}/) {
			$family{'funeral'}->{'date'} = $1;
			if($family{'funeral'}->{'date'} =~ /(.+?)\sat\s(.+)/) {
				# Wednesday 9th March at 1.15pm.  Friends etc. etc.
				$family{'funeral'}->{'date'} = $1;
				$family{'funeral'}->{'time'} = $2;
			}
		}
	} elsif($text =~ /funeral services.+\sat\s(.+)\sat\s(.+),\swith\s/i) {
		$family{funeral} = {
			time	 => $1,
			location => $2
		};
	} elsif($text =~ /funeral services.+\sat\s(.+),\swith\s/i) {
		$family{funeral} = { location => $1 }
	}

	# Extract father-in-law and mother-in-law information (if present)
	if($text =~ /father-in-law to\s+([A-Za-z\s]+)/) {
		my $father_in_law = $1;
		$family{children_in_law} = [{ name => $father_in_law }];
	} elsif($text =~ /mother-in-law to\s+([A-Za-z\s]+)/i) {
		my $mother_in_law = $1;
		$family{children_in_law} = [ split /\s*(?:,|and)\s*/i, ($text =~ /mother-in-law to\s+([^\.;]+)/i)[0] || '' ];
		if(scalar($family{children_in_law} == 0)) {
			$family{children_in_law} = [{ name => $mother_in_law }];
		}
	}

	# Extract aunt information
	if($text =~ /niece of\s+([A-Za-z]+)/) {
		my $aunt = $1;
		$family{aunt} = [{ 'name' => $aunt }];
	}

	# Birth info
	if($text =~ /[^\b]Born in ([^,]+),.*?\b(?:on\s+)?([A-Z][a-z]+ \d{1,2}, \d{4})/i) {
		$family{birth} = {
			place => $1,
			date => $2,
		}
	} elsif($text =~ /[^\b]Born in ([a-z,\.\s]+)\s+on\s+(.+)/i) {
		$family{'birth'}->{'place'} = $1;
		if(my $location = _extract_location($1)) {
			$family{'birth'}->{'location'} = $location;
		}
		if(my $dt = _extract_date($2)) {
			$family{'birth'}->{date} = $dt->ymd('/');
		}
		$family{'birth'}->{'place'} =~ s/\s+$//;
	} elsif($text =~ /S?he was born (.+)\sin ([a-z,\.\s]+)\s+to\s+(.+?)\sand\s(.+?)\./i) {
		$family{'birth'}->{'place'} = $2;
		my $father = $3;
		my $mother = $4;
		eval {
			if(my $dt = DateTime::Format::Text->parse_datetime($1)) {
				$family{'birth'}->{date} = $dt->ymd('/');
			}
		};
		# TODO
		# if($verbose && $@) {
			# Carp::carp($@);
		# }
		if($mother =~ /(.+)\s+\((.+)\)\s+(.+)/) {
			$mother = "$1 $2";
		}
		if($father =~ /(.+?)\.\s\s/) {
			$father = $1;
		}
		$family{parents} = {
			father => { name => $father },
			mother => { name => $mother }
		};
		if($text =~ /survived by (his|her) (father|mother)[\s,;]/i) {
			$family{parents}->{$2}->{'status'} = 'living';
		}
	} elsif($text =~ /[^\b]S?he was born\s*(?:on\s+)?([A-Z][a-z]+ \d{1,2}, \d{4})[,\s]+(?:in\s+)([^,]+)?/i) {
		if(my $dt = _extract_date($1)) {
			$family{'birth'}->{date} = $dt->ymd('/');
		}
		if($2) {
			$family{'birth'}->{'location'} = $2;
		}
	}

	# Date of death
	if($text =~ /\bpassed away\b.*?\b(?:on\s+)?([A-Z]+ \d{1,2}, \d{4})/i) {
		$family{death}->{date} = $1;
		$family{death}->{datetime} = _extract_date($1);
	}

	# Age at death
	if($text =~ /,\s(\d{1,3}), of\s/) {
		if($1 < 110) {
			$family{'death'}->{'age'} = $1;
		}
	}

	# Place of death
	if($text =~ /\b(?:passed away|died)\b([a-z0-9\s,]+)\sat\s+(.+?)\./i) {
		my $place = $2;
		if($place =~ /(.+)\s+on\s+([A-Z]+ \d{1,2}, \d{4})/i) {
			$place = $1;
			$family{death}->{date} = $2;
		} elsif($place =~ /(.+)\son\s(.+)/) {
			$place = $1;
			if(my $dt = _extract_date($2)) {
				$family{death}->{date} = $dt->ymd('/');
			}
		}
		$place =~ s/^\bthe residence,\s//;
		$place =~ s/\bafter a.*$//;
		$place =~ s/,\s+$//;
		$family{death}->{place} = $place;
	}

	# Remove blank fields from the main family hash
	%family = map { $_ => $family{$_} } grep { defined $family{$_} && $family{$_} ne '' } keys %family;

	# Remove empty arrays the family hash
	foreach my $key (keys %family) {
		if(ref($family{$key}) eq 'ARRAY') {
			$family{$key} = [ grep { /\S/ } @{$family{$key}} ];
			if(@{$family{$key}} == 0) {
				delete $family{$key};
			}
		}
	}

	return if(!scalar keys(%family));

	return Return::Set::set_return(\%family, { type => 'hashref', 'min' => 1, 'max' => 10 });
}

sub _extract_date
{
	my $text = shift;
	my $parser = DateTime::Format::Text->new();
	my $dt;

	eval { $dt = $parser->parse_datetime($text); };
	return $dt if $dt && !$@;
	return undef;
}

sub _extract_location {
	my $place_text = shift;

	$geocoder ||= Geo::Coder::List->new()->push(Geo::Coder::Free->new());
	my @locations = $geocoder->geocode(location => $place_text);	# Use array to improve caching

	return unless scalar(@locations);

	my $result = $locations[0];

	if(ref($result)) {
		return {
			raw => $place_text,
			# city => $result->{components}{city} || $result->{components}{town},
			# region => $result->{components}{state},
			# country => $result->{components}{country},
			latitude => $result->latitude(),
			longitude => $result->longitude()
		};
	}
	return {
		raw => $place_text,
		# city => $result->{components}{city} || $result->{components}{town},
		# region => $result->{components}{state},
		# country => $result->{components}{country},
		latitude => $result->{'latitude'},
		longitude => $result->{'longitude'}
	};
}


=head1 AUTHOR

Nigel Horne, C<< <njh at nigelhorne.com> >>

=head1 SEE ALSO

Test coverage report: L<https://nigelhorne.github.io/Genealogy-Obituary-Parser/coverage/>

=head1 SUPPORT

This module is provided as-is without any warranty.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1;
