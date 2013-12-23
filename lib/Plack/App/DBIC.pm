package Plack::App::DBIC;

use strict;
use warnings;

use Data::Dumper;
use parent 'Plack::Component';
use Plack::Request;
use Plack::Response;
use Plack::Util::Accessor qw(schema _registered_sources);
use DBIx::Class;
use DBIx::Class::Schema::Loader;
use JSON;

sub call {
    my $self = shift;
    my $env  = shift;

    my $req  = Plack::Request->new($env);
    my $path_info  = $req->path;

    my (undef,$resultset,$args) = split "/", $req->path_info;
    my @args = ($args =~ /,/ ? (split ",", $args) : $args);

    if ( my $rs = $self->schema->resultset($resultset) ) {
        my ($primary) = $rs->result_source->primary_columns();

        if ( $req->method eq 'GET' ) {
            $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

            my @ret = $rs->search({
                $primary => { -in => \@args },
            });

            my $response = Plack::Response->new();
            if ( @ret ) {
                $response->status(200);
                $response->content_type('data/json');

                $response->body(encode_json([ map { $_->{_column_data} } @ret ]));

                return $response->finalize;
            }
            
        }
        elsif ( $req->method eq 'POST')  {

        }
        elsif ( $req->method eq 'PUT' ) {

        }
        elsif ( $req->method eq 'DELETE' ) {

            $rs->search({
                $primary => { -in => \@args },
            });

            my $ret = $rs->delete;
            
            my $res = $eq->new_response(200);
            return $res->finalize;
        }
    }

}


1;
