use strict;
use warnings;

use Data::Dumper;
use Test::Most;
use Genealogy::Obituary::Parse qw(parse_obituary extract_family_info);

my $text = "She is survived by her husband Paul, daughters Anna and Lucy, and grandchildren Jake and Emma.";

my $rel = parse_obituary($text);

# diag (Data::Dumper->new([$rel])->Dump());

ok(defined $rel->{spouse}, 'Spouse field is defined');
diag explain $rel unless defined $rel->{spouse};

is_deeply $rel->{spouse}, ['Paul'], 'Extracted spouse';
is_deeply $rel->{children}, ['Anna', 'Lucy'], 'Extracted children';
is_deeply $rel->{grandchildren}, ['Jake', 'Emma'], 'Extracted grandchildren';

$rel = extract_family_info($text);

# diag (Data::Dumper->new([$rel])->Dump());
done_testing();
