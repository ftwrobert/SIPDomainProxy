package SIPDomainProxyWeb::Controller::User;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(decode_json encode_json);
use Digest;

sub verify_auth {
  my $self = shift;
  if (defined $self->session('username')) {
    return 1;
  }
  else {

    $self->respond_to(
      html => sub {
        $self->flash('requested' => $self->req->url);
        $self->redirect_to($self->url_for('login')->to_string);
        return undef;
      },
      cnjson => sub {
        $self->render(
          text   => $self->url_for('login')->to_string,
          status => 401
        );
      }
    );
  }
  return undef;
}

sub login {
  my $self = shift;

  $self->stash(
    'requested' => (
      defined $self->flash('requested')
      ? $self->flash('requested')
      : $self->url_for('/')
    )
  );

  # Let's try logging in
  my $config   = $self->app->config;
  my $username = $self->param('username') || '';
  my $password = $self->param('password') || '';
  my $db       = $self->app->pg->db;
  my $bcrypt   = Digest->new('Bcrypt');
  $bcrypt->cost(7);
  $bcrypt->salt($config->{salt});
  $bcrypt->add($password);
  my $query = 'SELECT id FROM users WHERE username = ? AND password = ?';

  if ($db->query($query, $username, $bcrypt->b64digest)->rows()) {
    $self->session(username => $username);
    $self->redirect_to($self->param('requested'));
    return 1;
  }

  # Well, ya gotta do so..
  $self->render;
  return undef;
}

sub logout {
  my $self = shift;
  $self->session(expires => 1);
  $self->redirect_to('/login');
}

1;
