package SIPDomainProxyWeb;
use Mojo::Base 'Mojolicious';
use Mojo::Pg;
use Mojo::Promise;
use Mojo::IOLoop;

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

  $auth->get('/domains')
       ->to('domain#domain')
       ->name('domain');
  $auth->post('/domains')
       ->to('domain#add_domain');
  $auth->post('/domains/rm/:id' => [id => q/\d+/])
       ->to('domain#remove_domain')
       ->name('rmdomain');

  $auth->get('/customers')
       ->to('customer#customers')
       ->name('customers');
  $auth->post('/customers')
       ->to('customer#add_customer');
  $auth->get('/customer/:id' => [id => q/\d+/])
       ->to('customer#customer')
       ->name('customer');
  $auth->post('/customer/:id' => [id => q/\d+/])
       ->to('customer#mod_customer');
  $auth->post('/customer/:id/add_billing_group' => [id => q/\d+/])
       ->to('billing_group#add_billing_group')
       ->name('add_billing_group');
  $auth->post('/customers/rm/:id' => [id => q/\d+/])
       ->to('customer#remove_customer')
       ->name('rmcustomer');

  $auth->get('/billing_group/:id' => [id => q/\d+/])
       ->to('billing_group#billing_group')
       ->name('billing_group');
  $auth->post('/billing_group/:id' => [id => q/\d+/])
       ->to('billing_group#mod_billing_group');
  $auth->post('/billing_group/rm/:id' => [id => q/\d+/])
       ->to('billing_group#remove_billing_group')
       ->name('rmbilling_group');
  $auth->post('/billing_group/:id/numbers' => [id => q/\d+/])
       ->to('number#add_tns')
       ->name('numbers');
  $auth->post('/billing_group/:id/numbers/rm' => [id => q/\d+/])
       ->to('number#remove_tns')
       ->name('rmnumbers');

  $auth->post('/billing_group/:id/auths' => [id => q/\d+/])
       ->to('authentication#add_auth')
       ->name('auths');

  $auth->post('/billing_group/:id/auths/:aid' => [id => q/\d+/,
                                                  aid => q/\d+/])
       ->to('authentication#mod_auth')
       ->name('mod_auth');
  $auth->post('/billing_group/:id/auths/:aid/rm' => [id => q/\d+/,
                                                     aid => q/\d+/])
       ->to('authentication#remove_auth')
       ->name('rmauth');

  $auth->get('/registrations')
       ->to('registrations#registrations')
       ->name('registrations');

  $auth->get('/search')
       ->to('search#search')
       ->name('search');

  $auth->get('/settings')
       ->to('settings#settings')
       ->name('settings');
  $auth->post('/users')
       ->to('user#mod_username_password')
       ->name('users');
  $auth->post('/users/rm')
       ->to('user#delete_user')
       ->name('rmuser');

  $auth->post('/proxies')
       ->to('proxy#add_proxy')
       ->name('proxy');
  $auth->post('/proxies/rm/:id' => [id => q/\d+/)
       ->to('proxy#delete_proxy')
       ->name('rmproxy');
}

1;
