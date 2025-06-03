use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Genealogy::Obituary::Parse',
    VERSION_FROM => 'lib/Genealogy/Obituary/Parse.pm',
    AUTHOR       => 'Nigel Horne',
    ABSTRACT     => 'Extract relatives from obituary text for genealogical purposes',
    LICENSE      => 'GPL',
    PREREQ_PM    => {
        'Test::Most' => 0,
    },
);
