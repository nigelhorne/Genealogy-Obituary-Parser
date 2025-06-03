use strict;
use warnings;
use Test::Most;
use Genealogy::Obituary::Parse qw(parse_obituary);

my $text = <<'END';
He is survived by his wife Mary, sons John and David, and grandchildren Sophie, Liam, and Ava.
His parents were George and Helen.
He also leaves behind his sister Claire.
END

my $rel = parse_obituary($text);

is_deeply $rel->{spouse},        ['Mary'],                        'Extracted spouse';
is_deeply $rel->{children},      ['John', 'David'],              'Extracted children';
is_deeply $rel->{grandchildren}, ['Sophie', 'Liam', 'Ava'],      'Extracted grandchildren';
is_deeply $rel->{parents},       ['George', 'Helen'],            'Extracted parents';
is_deeply $rel->{siblings},      ['Claire'],                     'Extracted siblings';

done_testing;
