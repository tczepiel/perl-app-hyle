use strict;
use warnings;

use Carp::Always;
use Data::Dumper;
use File::Temp qw(tempdir);
use DBI;
use DBIx::Class;
use DBIx::Class::Schema::Loader;
use Class::Load;
use Getopt::Long;
use Plack::Runner;

my $dsn;
GetOptions("dsn=s" => \$dsn)
    or die "can't get the options";

my $tempdir = tempdir();
DBIx::Class::Schema::Loader::make_schema_at(
    'Schema',
    {debug => 1, dump_directory => $tempdir },
    [ $dsn,  "", "", {} ],
);


push @INC, $tempdir;

eval {
    require MySchema;
    MySchema->import();
    1;
} or do {
    my $err = $@ || "unknown";
    die $err;
};

# get the scema
my $schema = MySchema->connect($dsn, "", "");

my $app    = Plack::App::DBIC->new( schema => $schema )->to_app;
my $runner = Plack::Runner->new();
$runner->parse_options(@ARGV);

$runner->run($app);



unlink $tempdir if -e $tempdir;
