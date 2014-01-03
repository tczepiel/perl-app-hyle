package Plack::App::DBIC;

use strict;
use warnings;
use Data::Dumper;
use parent 'Plack::Component';
use Plack::Request;
use Plack::Response;
use Plack::Util::Accessor qw(schema serializers);
use DBIx::Class;

sub serializer {
    my $self    = shift;
    my $request = shift;

    my $serializers     = $self->serializers || $self->serializers({});
    my ($accept_format) = $request->headers->header("Accept");

    return $serializers->{$accept_format} if exists $serializers->{$accept_format};

    # default to JSON
    require JSON;
    return sub {
        return ('data/json', JSON::encode_json(@_));
    };
}

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

            my @ret = $rs->search({
                    $primary => { -in => \@args },
                },
                {
                    result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                }
            );

            my $response = Plack::Response->new();
            if ( @ret ) {

                $response->status(200);

                my ($content_type, $data) = $self->serializer($req)->(\@ret);

                $response->content_type($content_type);
                $response->body( $data );

                return $response->finalize;
            }

            $response->status(404);

            return $response->finalize;
            
        }
        elsif ( $req->method eq 'POST')  {
           my $ret = $rs->find($args[0]);

          $ret->update(%{ $req->body_parameters });

          my $res = $req->new_response(200);
          return $res->finalize;

        }
        elsif ( $req->method eq 'PUT' ) {

            my $res = $rs->create(\%{
                $req->body_parameters
            });
            my @primary = $rs->result_source->primary_columns();

            my $resp = $req->new_response(200);

            my ($content_type,$data) = $self->serializer($req)->((map { $_ => $res->$_ } @primary));
            $resp->content_type($content_type);
            $resp->body($data);

            return $resp->finalize();
        }
        elsif ( $req->method eq 'DELETE' ) {

            $rs->search({
                $primary => { -in => \@args },
            })->delete();

            my $res = $req->new_response(200);
            return $res->finalize;
        }
    }
    else {
        my $resp = Plack::Response->new(404);
        return $resp->finalize;
    }
}


1;
