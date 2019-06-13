package SIPDomainProxyWeb::Controller::Proxy;
use Mojo::Base 'Mojolicious::Controller';

sub add_proxy {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1 = <<SQL;
INSERT INTO rpc_hosts (name, addr)
VALUES (?,?);
SQL
  $db->query($q1 => ($self->param('name'), $self->param('addr')));
  $self->redirect_to('settings');
}

sub delete_proxy {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1 = <<SQL;
DELETE FROM rpc_hosts
WHERE id = ?;
SQL
  $db->query($q1, ($self->param('id')));
  $self->redirect_to('settings');
}

1;
