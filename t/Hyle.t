use strict;
use warnings;

use Test::More;
use Test::Exception;
use lib 't';
use MySchema;
use Hyle;
use Plack::Test;
use HTTP::Request::Common qw();
use HTTP::Request;
use JSON;

my $dbfile =':memory:';
my $schema = MySchema->connect("dbi:SQLite:dbname=$dbfile","","");

my $app  = Hyle->new(schema => $schema)->to_app;

{
    my $dbh = $schema->storage->dbh;
    $dbh->do("CREATE TABLE A (a int not null)");
    $dbh->do("INSERT INTO A VALUES (1)");
}

my $test = Plack::Test->create($app);

# GET
lives_ok(sub {
   my $res = $test->request(
    +HTTP::Request->new(GET => 'A/1')
   );

   #diag($res->decoded_content);
   ok($res->is_success,"response is succesful");
   cmp_ok($res->code,'==', 200, "response code 200 OK");

   cmp_ok($res->headers->header("Content-Type"), 'eq', "data/json","content type header ok");

   ok(defined $res->headers->header("Content-Length"), "content length header defined");
   
   cmp_ok($res->headers->header("Content-Length"), '==', length($res->decoded_content), "content length matches response");

    my $ret;
   
   lives_ok(sub {
       $ret = JSON::decode_json($res->decoded_content);
   }, "can deserialize the body");

   cmp_ok(ref($ret),'eq','ARRAY',"response isa ARRAYREF");
   ok(@$ret == 1, "only one result returned");

   ok($ret->[0]{a} == 1, "returned content matches input");

}, "get works");

lives_ok(sub {
    my $req = HTTP::Request::Common::HEAD 'A/1';
    my $res = $test->request($req);

    ok($res->is_success, "response is succesful");
    cmp_ok($res->code, '==', 200, "response code 200 OK");
    
    ok(!$res->decoded_content, "no content returned");

}," HEAD works");

# POST ( update )
lives_ok(sub {
    my $req = HTTP::Request::Common::POST 'A/1', [ a => 2 ];
    my $res = $test->request($req);
    
    cmp_ok($res->code, '==', 200, "response code 200 OK");
    #diag($res->decoded_content());

},'POST(update) works');

# JSONP
lives_ok(sub {
    my $req = HTTP::Request::Common::POST 'A/1?jsonp=foo', { a => 1 };
    my $res = $test->request($req);

    cmp_ok($res->code,'==',200,"code returned : 200 OK");

    cmp_ok($res->decoded_content,'eq', '[1]', "response retured as expected");

},"JSONP method works");

# PUT (update)
lives_ok(sub {
    my $request = HTTP::Request->new();
    $request->method("PUT");
    $request->uri("A/1");
    $request->header("Content-Type" => "application/x-www-form-urlencoded");
    $request->content("a=7");

    my $res = $test->request($request);
    #diag($res->decoded_content);

    cmp_ok($res->code,"==",200, "response code for update ok");

    my $res2 = $test->request(
     +HTTP::Request->new(GET => 'A/7')
     );

    #diag($res2->decoded_content);
    ok($res2->is_success,"response is succesful");
    cmp_ok($res2->code,"==",200, "response code ok");

    lives_ok(sub {
        #diag($res2->decoded_content());
        my $ret = JSON::decode_json($res2->decoded_content());

        ok(ref($ret->[0]) eq 'HASH', 'returned data isa HASHREF');
        cmp_ok($ret->[0]{a}, "==",7,"value updated ok");

    },"decoded response ok");

}, "put works");

# DELETE
lives_ok(sub {
    my $req = HTTP::Request->new(DELETE=> 'A/1');
    my $res = $test->request($req);
    
    ok($res->code == 200, "response code 200 OK");

    $req = HTTP::Request->new(GET => 'A/1');
    $res = $test->request($req);

    ok($res->code == 404, "resource deleted succesfully");

},'DELETE works');

# POST (create)
lives_ok(sub {
    my $req = HTTP::Request::Common::POST 'A/', [ a => 0 ];
    my $res = $test->request($req);

    cmp_ok($res->code,'==',200, "resource created ok");
    #diag($res->decoded_content());
    my $ret;
    lives_ok(sub {
        $ret = JSON::decode_json($res->decoded_content());

        ok(ref($ret) eq 'HASH', 'returned data isa HASHREF');
        ok(keys %$ret, "primary keys returned ok");

    },"decoded response ok");

}, "POST(create) works");


# JSONP - not found
lives_ok(sub {
    my $req = HTTP::Request::Common::POST 'A/1?jsonp=foo', { a => 1 };
    my $res = $test->request($req);

    cmp_ok($res->code,'==',404);

},"JSONP method works");

done_testing();
