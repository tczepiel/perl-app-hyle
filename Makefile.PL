use strict;
use warnings;

use ExtUtils::MakeMaker;
WriteMakefile(
    NAME              => 'Plack::App::DBIC',
    VERSION_FROM      => 'lib/Plack/App/DBIC.pm',
    PREREQ_PM         => {
        Plack            => 0,
        parent           => 0,
        JSON             => 0,
        'DBIx::Class'    => 0,
        'Package::Stash' => 0,
        'HTTP::Message'  => 0,
    },
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/Plack/App/DBIC.pm',
       AUTHOR         => 'A. U. Thor <tjmc@localdomain>') : ()),
);
