package MySchema::Result::A;

use base qw/DBIx::Class::Core/;
__PACKAGE__->table('A');
__PACKAGE__->add_columns(qw/a/);
__PACKAGE__->set_primary_key('a');

use Attributes::Simple qw(CODE);

sub foo :JSONP {
    my $self = shift;
    my %args = @_;

    return 1;
}
 
1;
