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
use Carp qw(croak);

our $VERSION = '0.1';

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

    # update worked ok, let's bail out here
    return $resp if $res->in_storage();
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
        my $response        = $dispatch_method->($self,$req,$resultset,$rs,@args);

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

=head1 restify

=head1 HTTP Methods

=head2 GET

=head2 POST - update/create

=head2 DELETE


=head2 OBJECT ATTRIBUTES

=head3 serializers

=head3 override

=head3 result_sources

=head3 serializers

=head2 Overriding HTTP method handlers

subclass, global overrides, method implementation in resultsource class

