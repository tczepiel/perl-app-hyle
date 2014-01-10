package Plack::App::DBIC;

use strict;
use warnings;
use parent 'Plack::Component';
use Plack::Request;
use Plack::Response;
use Plack::Util::Accessor
    qw(schema serializers override result_sources validator);
use DBIx::Class;
use Package::Stash;
use Carp qw(croak carp);
use attributes qw();

our $VERSION = '0.1';

sub __jsonp_method {
    my ($self,$req,$resultset,$rs,$jsonp_method_name,@args) = @_;

    my ($primary) = $rs->result_source->primary_columns();
    my %params = %{$req->body_parameters()};

    my ($object) = $rs->search({
        $primary => { -in => \@args },
    })->first;

    return $req->new_response(404)
        unless $object;

    my $result_source_class  = $rs->result_source->result_class;
    my $jsonp_method_coderef = $object->can($jsonp_method_name);

    if ( grep { $_ eq 'JSONP' } attributes::get($jsonp_method_coderef) ) {
        # method has a 'JSONP' attribute.
        my @ret;
        eval {
            @ret = $object->$jsonp_method_name(%params);
            1;
        } or do {
            my $err = $@ || "unknown error";
            carp sprintf "Died executing %s, error: %s, parameters %s",
               $jsonp_method_name,
               $err,
               join ",", map { "$_=>$params{$_}" } keys %params;

               return $req->new_response(500); # internal server error
        };

        
        my $resp = $req->new_response(204); # ok, no content
        if ( @ret ) {
            $resp->status(200);

            my ($content_type, $data) = $self->serializer($req)->(\@ret);
            $resp->body($data);
            $resp->content_type($content_type);

            return $resp;
        }
    }
    else {
        return $req->new_response(501); #not implemented
    }

}

sub __GET {
    my ($self,$req,$resultset,$rs,@args) = @_;

    my ($primary) = $rs->result_source->primary_columns();

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
    }
    else {
        $response->status(404);
    }

    return $response;
}

sub __POST {
    my ($self,$req,$resultset,$rs,@args) = @_;

    my $body_params = $req->body_parameters;
    my $params      = ref($body_params) && $body_params->isa("Hash::MultiValue") 
                      ? $body_params->as_hashref 
                      : $body_params;

    my $res     = $rs->find_or_new($params);
    my $resp    = $req->new_response(200);

    # are the updetes on post enabled?
    if ( $res->in_storage() && $self->allow_post_updates ) {
        $res->update();
        return $resp;
    }
    elsif ( $res->in_storage() ) {
        $resp->status(409); # conflict
        return $resp;
    }

    $res->insert();

    #return primary keys back
    my @primary = $rs->result_source->primary_columns();

    my ($content_type,$data) 
        = $self->serializer($req)->({ (map { $_ => $res->get_column($_) } @primary) });

    $resp->content_type($content_type);
    $resp->body($data);

    return $resp;
}

sub __DELETE {
    my ($self,$req,$resultset,$rs,@args) = @_;

    my ($primary) = $rs->result_source->primary_columns();
    $rs->search({
        $primary => { -in => \@args },
    })->delete();

    return $req->new_response(200);
}

our $rest2subref;
sub _rest2subref {
    my ($self,$req,$resultset) = @_;
    my $method = $req->method();

    my $subref = $rest2subref->{$resultset}{$method} ||= do {
        my $rs    = $self->schema->resultset($resultset);
        my $class = $rs->result_source->result_class;

        if ( my $coderef = $class->can($method) ) {
            return $coderef;
        }
        elsif ( my $overrides = $self->override ) {
            croak "override parameter must be a hashref"
                unless ref $overrides eq 'HASH';
            my $coderef = $overrides->{$resultset}{$method} || $overrides->{$method};
            return $coderef if $coderef;
        }

        my $p = Package::Stash->new(__PACKAGE__);
        return $p->get_symbol('&__'.$method);
    };

    return $subref;
}

sub serializer {
    my $self    = shift;
    my $request = shift;

    my $serializers     = $self->serializers || $self->serializers({});
    my ($accept_format) = $request->headers->header("Accept");

    return $serializers->{$accept_format} if $accept_format && exists $serializers->{$accept_format};

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

    if ( (my $rs = $self->schema->resultset($resultset))
        && (!$self->result_sources || exists$self->result_sources->{$resultset})) {

        # parameter validation
        if ( $self->validator && (my $params = $req->body_parameters) ) {
            my $ret = $self->validator->check_params($resultset,$req);
            unless ($ret) {
                # bad request/unprocessable entity
                return $req->new_response(422);
            }
        }

        my $dispatch_method = $self->_rest2subref($req,$resultset);
        my $response;

        my ($jsonp_method_name,$jsonp_callback_function) = do {
            my $query = $req->query_parameters;
            @{$query}{qw(jsonp jsonp_callback)};
        };

        if ( $jsonp_method_name ) {
            # jsonp call
            $response = $self->__jsonp_method($req,$resultset,$rs,$jsonp_method_name,@args);
            if ($jsonp_callback_function && $response->body) {
                my $body = $response->body;
                $response->body( "$jsonp_callback_function ($body)" );
            }
        }
        else {
            $response = $dispatch_method->($self,$req,$resultset,$rs,@args);
        }

        return $response->finalize;
    }
    else {
        my $resp = Plack::Response->new(404);
        return $resp->finalize;
    }
}

1;

__END__

=head1 NAME

Plack::App::DBIC

=head1 DESCRIPTION

=head1 SYNOPSIS

    # cpanm Plack::App::DBIC

    # restify  --dsn'dbi::SQLite::dbname=file.db' --username=... --password= ....

    # curl http://localhost:8000/collection/id/7


    # curl -X DELETE ...

    # .... 
    #
    # more configuration 
    
    my $schema = DBIx::Class->connect(...);

    my $app = Plack::App::DBIC->new(
        schema => $schema,
        ... other options ...
    );

    # make a custom mount with plack::builder ....

    builder {
        mount => "/somewhere" => $app;
        mount => /somethingElse" => $other_app;
    };

    

=head1 restify

=head1 HTTP Methods

=head2 GET

=head2 POST - update/create

=head2 DELETE


=head2 OBJECT ATTRIBUTES

=head3 serializers

    %serializers = (
        "application/json" => sub { ... },
        ...,
    );

defaults to 'data/json', response content type and JSON::encode_json serialization function.

=head3 override

    %overrides = (
        'artist' => { GET => sub { ... } },
        ...,
    );

allows overriding particular methods.

if the class itself implements the GET/POST/DELETE etc., methods, those will be invoked first, then followed by the check for an appropriate method in the %overrides hash, if no method is found, the default __GET, __POST (etc) implementation will be used.

=head3 result_sources

    %result_sources = (
        artist => 1,
        cds    => 1,
        ...
    );

Expose only the following result sources in the api.

=head3 allow_post_updates

If true, the POST will either create or update an existing resource. It's false by default, on conflict of an existing respource, a 409 HTTP response is returned.

=head2 Overriding HTTP method handlers

subclass, global overrides, method implementation in resultsource class

=head2 Support for JSONP

this module is able to include information about potential methods of a result source, or any other subref implementing it.

i.e.

my $jsonp_method :JSONP = sub {
    my ($self,$req,$resultset,$rs,$jsonp_method_name,@args) = @_;

    $rs->search_where({
        column => { -in => [ \@args ] },
    });

    # ....
    my $response = $req->new_response(200);
    $response->body( $self->serializer( ... ) );
};

GET http://localhost:3000/artist/id/7

200 OK

{ "a": 1, "b":2, "__jsonp_methods:["foo"] }

var someFancyObject = { ...  };
someFancyObject.foo = function( ) { ... };

var ret = someFancyObject.foo({ meh => 1 },{ callback => function() { ... }} );

POST http://localhost:8000/artist/id/7?jsonp=foo&jsonp_callback=gotData
meh: 1

...






