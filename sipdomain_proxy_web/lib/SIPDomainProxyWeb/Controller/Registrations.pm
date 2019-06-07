package SIPDomainProxyWeb::Controller::Registrations;
use Mojo::Base 'Mojolicious::Controller';

sub registrations {
  my $self = shift;
  my $db = $self->pg->db;
  my $domain = defined $self->param('domain') ? $self->param('domain') : '';
  $self->stash(domain => $domain);
  my $user = defined $self->param('user') ? $self->param('user') : '';
  $self->stash(user => $user);
  my $q1 = "SELECT id, domain FROM domain ORDER BY domain;";
  my $r1 = $db->query($q1);
  $self->stash(domains => $r1);
  my $where;
  if ($domain ne '' && $user ne '') {
    $where = "WHERE domain = ? AND username = ?";
  }
  elsif ($domain ne '') {
    $where = "WHERE domain = ?";
  }
  elsif ($user ne '') {
    $where = "WHERE username = ?";
  }
  else {
    $where = "";
  }
  my $q2 = <<SQL;
SELECT username, domain, contact, received, last_modified, user_agent
FROM location
$where
ORDER BY domain, username;
SQL
  my $r2;
  if ($domain ne '' && $user ne '') {
    $r2 = $db->query($q2 => ($domain, $user));
  }
  elsif ($domain ne '') {
    $r2 = $db->query($q2 => ($domain));
  }
  elsif ($user ne '') {
    $r2 = $db->query($q2 => ($user));
  }
  else {
    $r2 = $db->query($q2);
  }
  $self->stash(locations => $r2);
  $self->render(template => 'registrations/registrations');
}

1;
