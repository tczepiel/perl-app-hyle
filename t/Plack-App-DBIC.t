use strict;
use warnings;

use Test::More qw(no_plan);
use Test::Exception;
use lib 't';
use MySchema;
use Plack::App::DBIC;
use Plack::Test;
use HTTP::Request;
use JSON;

my $schema = MySchema->connect('dbi:SQLite:memory');

my $app  = Plack::App::DBIC->new(schema => $schema)->to_app;
my $test = Plack::Test->create($app);

# GET
lives_ok(sub {
   my $res = $test->request(
    +HTTP::Request->new(GET => 'a/1')
   );

   ok($res->is_success,"response is succesful");
   ok($res->code == 200, "response code 200 OK");

    my $ret;
   
   lives_ok(sub {
       $ret = JSON::decode_json($res->decoded_content);
   }, "can deserialize the body");

    ok($ret->{a} == 1, "returned content matches input");

}, "get works");

# POST ( update )
lives_ok(sub {
    my $req = HTTP::Request->new(POST => 'a/1');
    $req->content(JSON::encode_json({a => 2}));
    my $res = $test->request($req);
    
    ok($res->code == 200, "response code 200 OK");

},'POST works');

# DELETE
lives_ok(sub {
    my $req = HTTP::Request->new(DELETE=> 'a/1');
    my $res = $test->request($req);
    
    ok($res->code == 200, "response code 200 OK");

    $req = HTTP::Request->new(GET => 'a/1');
    $res = $test->request($req);

    ok($res->code == 404, "resource deleted succesfully");

},'POST works');

# PUT (create)
lives_ok(sub {
    my $req = HTTP::Request->new(PUT => 'a/2');
    $req->content(JSON::encode_json({a => 0}));
    my $res = $test->request($req);

    ok($res->code == 200, "resource created ok");
    my $ret;
    lives_ok(sub {
        $ret = JSON::decode_json($res->decoded_content());

        ok(ref($ret) eq 'HASH', 'returned data isa HASHREF');
        ok(keys %$ret, "primary keys returned ok");

    },"decoded response ok");

}, "PUT works");


