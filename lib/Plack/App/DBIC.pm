package Plack::App::DBIC;

use strict;
use warnings;

use Data::Dumper;
use parent 'Plack::Component';
use Plack::Request;
use Plack::Response;
use Plack::Util::Accessor qw(schema _registered_sources);
use DBIx::Class;
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

            $response->status(404) unless $response->status;

            return $response->finalize;
            
        }
        elsif ( $req->method eq 'POST')  {
           my $ret = $rs->find($args[0]);

          $ret->update(%{ $req->body_parameters });

          my $res = $req->new_response(200);
          return $res->finalize;

        }
        elsif ( $req->method eq 'PUT' ) {

            my $res = $rs->create(%{
                $req->body_parameters
            });
            my @primary = $rs->result_source->primary_columns();

            my $resp = $req->new_response(200);
            $resp->content_type("data/json");
            $resp->body(
                encode_json([
                    map { $_ => $res->$_ } @primary
                ])
            );

            return $resp->finalize();
        }
        elsif ( $req->method eq 'DELETE' ) {

            $rs->search({
                $primary => { -in => \@args },
            });

            my $ret = $rs->delete;
            
            my $res = $req->new_response(200);
            return $res->finalize;
        }
    }
}


1;
