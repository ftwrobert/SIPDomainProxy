package SIPDomainProxyWeb::Controller::Settings;
use Mojo::Base 'Mojolicious::Controller';

sub settings {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1 = <<SQL;
SELECT username
FROM users
ORDER BY username;
SQL
  my $r1 = $db->query($q1);
  $self->stash(users => $r1);
  $self->dumper($r1);
  $self->render(template => 'settings/settings');
}

1;
