package MySchema::Result::A;

use base qw/DBIx::Class::Core/;
__PACKAGE__->table('A');
__PACKAGE__->add_columns(qw/a/);
__PACKAGE__->set_primary_key('a');

 
1;
