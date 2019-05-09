package SIPDomainProxyWeb;
use Mojo::Base 'Mojolicious';
use Mojo::Pg;

# This method will run once at server start
sub startup {
  my $self = shift;

  # !FIXME! Update this when ready for release
  $self->mode('development');

  # remove the default Mojo Command namespace and add ours,
  # then set our help message
  pop @{$self->commands->namespaces};
  push @{$self->commands->namespaces}, 'SIPDomainProxyWeb::Command';
  $self->commands->message(
    "Usage: APPLICATION COMMAND [OPTIONS]

Options (for all commands):
  --help          Get more information on a specific command

Commands:
"
  );

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config');
  say 'Loading config variables';
  say 'secrets=' . $config->{secrets};
  say 'salt=' . $config->{salt};
  say 'dbstr=' . $config->{dbstr};

  # Configure the application
  $self->secrets($config->{secrets});

  $self->helper( pg => sub { state $pg = Mojo::Pg->new( $config->{'dbstr'} ) });

  push @{$self->commands->namespaces}, 'SIPDomainProxyWeb::Command';

  # Add the MIME type Collection.next+JSON
  # https://www.iana.org/assignments/media-types/application/vnd.collection.next+json
  # Collection.next+JSON is an improvement upon Collection+JSON
  # https://www.iana.org/assignments/media-types/application/vnd.collection+json
  # I have placed a copy of each of these guides in public
  $self->types->type( cnjson => 'application/vnd.collection.next+json' );
  #
  my $plugins = Mojolicious::Plugins->new;
  $plugins->register_plugin( 'SIPDomainProxyWeb::Plugin::CollectionNextJSON', $self );

  # Router
  my $r = $self->routes;

  # Authenticaion and redirect-to-authentication
  my $auth = $r->under('/')->to('user#verify_auth');
  $r->any( [ 'GET', 'POST' ] => '/login' )->to('user#login');
  $r->any('/logout')->to('user#logout');

  $auth->any( '/' => sub {
    my $self = shift;
    $self->render( template => 'default' );
  });

}

1;
