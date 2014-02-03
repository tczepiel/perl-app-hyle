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
        'File::Temp'     => 0,
        DBI              => 0,
        'DBIx::Class::Schema::Loader' => 0,
        'Class::Load'    => 0,
        'Getopt::Long'   => 0,
        'Hash::MultiValue' => 0,
    },
    ($] >= 5.005 ?
      (ABSTRACT => "Simple REST endpoint app for db backend build with Plack and DBIC",
       AUTHOR         => 'Tomasz Czepiel <tjmc@cpan.org>') : ()),
    EXE_FILES => [ 'scripts/hyle.pl' ],
);
