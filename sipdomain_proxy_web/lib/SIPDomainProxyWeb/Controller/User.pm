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

sub mod_username_password {
  my $self = shift;
  my $db = $self->pg->db;

  if ($self->param('username') eq '' || $self->param('password') eq '') {
    $self->redirect_to('settings');
  }
  else {
    my $q1 = <<SQL;
INSERT INTO users (username, password)
VALUES (?,?)
ON CONFLICT (username) DO UPDATE SET password = EXCLUDED.password;
SQL
    my $config = $self->app->config;
    my $bcrypt = Digest->new('Bcrypt');
    $bcrypt->cost(7);
    $bcrypt->salt($config->{salt});
    $bcrypt->add($self->param('password'));
    $db->query($q1, ($self->param('username'), $bcrypt->b64digest));
    $self->redirect_to('settings');
  }
}

sub delete_user {
  my $self = shift;
  if ($self->param('username') eq $self->session('username')) {
    $self->redirect_to('settings');
  }
  else {
    my $db = $self->pg->db;
    my $q1 = "DELETE FROM users WHERE username = ?";
    $db->query($q1, ($self->param('username')));
    $self->redirect_to('settings');
  }
}

1;
