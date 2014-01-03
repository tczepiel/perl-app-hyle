package Plack::App::DBIC;

use strict;
use warnings;
use Data::Dumper;
use parent 'Plack::Component';
use Plack::Request;
use Plack::Response;
use Plack::Util::Accessor qw(schema serializers override);
use DBIx::Class;
use Package::Stash;
use Carp qw(croak);

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
    my $ret = $rs->find($args[0]);
    $ret->update(%{ $req->body_parameters });
    return $req->new_response(200);
}

sub __PUT {
    my ($self,$req,$resultset,$rs,@args) = @_;

    my $res = $rs->create(\%{
        $req->body_parameters
    });

    #return primary keys back
    my @primary = $rs->result_source->primary_columns();
    my $resp    = $req->new_response(200);
    my ($content_type,$data) 
        = $self->serializer($req)->((map { $_ => $res->$_ } @primary));

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
        my $rs = $self->schema->resultset($resultset);
        if ( my $coderef = $rs->can($method) ) {
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

        my $dispatch_method = $self->_rest2subref($req,$resultset);
        my $response        = $dispatch_method->($self,$req,$resultset,$rs,@args);

        return $response->finalize;
    }
    else {
        my $resp = Plack::Response->new(404);
        return $resp->finalize;
    }
}


1;
