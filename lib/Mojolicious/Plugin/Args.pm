package Mojolicious::Plugin::Args;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON 'decode_json';

sub register {
    my ( $self, $app, $opts ) = @_;
    $opts->{ '-want-detail' } //= 0 unless exists $opts->{ '-want-detail' };
    my $want_detail = delete $opts->{ '-want-detail' };

    $app->helper( args => sub {
        my $c = shift;
        my $stash = $c->stash;
        my %args;
        $args{ $_ } = $c->param( $_ ) for $c->param;
        $args{ $_ } = $c->stash( $_ ) for grep { defined $stash->{ $_ } } keys %args;
        my $type = $c->req->headers->header( 'Content-Type' );
        if ( ( $c->req->method ne 'GET' and $type and $type =~ 'application/json' ) or
             ( $c->req->method eq 'GET' and defined $stash->{format} and $stash->{format} eq 'json' and defined $args{json} ) ) {
            my @args = keys %args;
            my $json = decode_json( $c->req->method eq 'GET' ? delete $args{json} : $c->req->body );
            my @json = keys %{ $json };
            do {
                $args{__args}->{ $_ } = $args{ $_ }   for @args; # save to __priv
                $args{__json}->{ $_ } = $json->{ $_ } for @json; # for specific access
            } if $want_detail;
            $args{ $_ } = $json->{ $_ } for @json;
        }
        $stash->{args} = \%args;
        return wantarray ? %{ $stash->{args} } : $stash->{args};
    } );
}

# ABSTRACT: gives you back the request parameters as a simple %args hash, even if it's posted in json.
1;

=head1 SYNOPSIS

Route something like this:

    package App;
    use Mojo::Base 'Mojolicious';

    sub startup {
        my $self = shift;

        $self->plugin( 'Mojolicious::Plugin::Args' );

        my $r = $self->routes;

        $r->any( '/example/test' )->to( 'example#test' );
    }

Here's the controller:

    package App::Example;
    use Mojo::Base 'Mojolicious::Controller';

    sub test {
        my $self = shift;
        my %args = $self->args;

        $self->log->debug( 'args', $self->dumper( \%args ) );
        $self->render( json => \%args );
    }

Now send a POST to it (jQuery example):

    $.ajax( {
        type: 'POST'
        ,url: '/example/test'
        ,contentType: 'application/json'
        ,dataType: 'json'
        ,data: JSON.stringify( { foo: 'bar' } )
    } );

Inspect the response. Keen. Try a GET on the endpoint with ".json" typed (C</example/test.json>) and a json query string variable (C<?json=...>). Same result.

    $.ajax( {
        type: 'GET'
        ,url: '/example/test.json?json='+ JSON.stringify( { foo: 'bar' } )
    } );

Also, try regular query string vars (e.g. C<?foo=bar&baz=foo>) and form-url-encoded POST stuff. Works the same. All-in-one: no more dealing with the stupid C<param> helper.

=cut
