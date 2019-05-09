package SIPDomainProxyWeb::Command::setpass;
use Mojo::Base 'Mojolicious::Command';
use Digest;

has description => "Set a user's encrypted password.";
has usage       => "Usage: $0 setpass USERNAME NEW_PASSWORD\n";

sub run {
  my ($self, $username, $password) = @_;

  if (not defined $username or not defined $password) {
    die "You must specify a username and password.\n";
  }

  my $config = $self->app->config;
  my $db     = $self->app->pg->db;
  my $bcrypt = Digest->new('Bcrypt');
  $bcrypt->cost(7);
  $bcrypt->salt($config->{salt});
  $bcrypt->add($password);

  my $query = 'SELECT id FROM users WHERE username = ?';
  if ($db->query($query, $username)->rows()) {
    $query = 'UPDATE users SET password = ? WHERE username = ?';
    $db->query($query, $bcrypt->b64digest, $username);
  }
  else {
    $query = 'INSERT INTO users (username, password) VALUES (?,?)';
    $db->query($query, $username, $bcrypt->b64digest);
  }
}

1;
