package SIPDomainProxyWeb;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config');

  # Configure the application
  $self->secrets($config->{secrets});

  # For future use, we will replace the proxyctl command with the CLI version
  # of this application.
  #push @{$self->commands->namespaces}, 'SBCManager::Command';

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');
}

1;
