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
use Plack::App::DBIC;

my $dsn;
GetOptions("dsn=s" => \$dsn)
    or die "can't get the options";

my $tempdir = tempdir();
DBIx::Class::Schema::Loader::make_schema_at(
    'Schema',
    { dump_directory => $tempdir },
    [ $dsn,  "", "", {} ],
);


push @INC, $tempdir;

eval {
    require Schema;
    Schema->import();
    1;
} or do {
    my $err = $@ || "unknown";
    die $err;
};

# get the scema
my $schema = Schema->connect($dsn, "", "");

for my $source ($schema->sources() ) {
    # hack, add something as a primary column if no primary column(s) are defined
    my $source_class = $schema->source($source);
    next if $source_class->primary_columns();
 
    $source_class->set_primary_key($source_class->columns());
}

my $app    = Plack::App::DBIC->new( schema => $schema )->to_app;
my $runner = Plack::Runner->new();
$runner->parse_options(@ARGV);

$runner->run($app);

unlink $tempdir if -e $tempdir;
