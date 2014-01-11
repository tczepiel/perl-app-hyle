use strict;
use warnings;

use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'Hyle',
    VERSION_FROM      => 'lib/Hyle.pm',
    PREREQ_PM         => {
        Plack            => 0,
        parent           => 0,
        JSON             => 0,
        'DBIx::Class'    => 0,
        'Package::Stash' => 0,
        'HTTP::Message'  => 0,
    },
    ($] >= 5.005 ?
      (ABSTRACT => "Simle REST API implementation based on Plack",
       AUTHOR         => 'Tomasz Czepiel <tjmc@cpan.org>>') : ()),
    EXE_FILES => [ 'scripts/hyle.pl' ],
);
