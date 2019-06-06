package SIPDomainProxyWeb::Controller::Authentication;
use Mojo::Base 'Mojolicious::Controller';
use NetAddr::IP;
use Data::Dumper;

sub add_auth {
  my $self = shift;
  my $db = $self->pg->db;
  if ($self->param('username') eq '' && $self->param('addr') eq '') {
    $self->redirect_to('billing_group', id => $self->param('id'));
  }
  my $addr = 0;
  if ($self->param('addr') ne '') {
    $addr = new NetAddr::IP $self->param('addr');
    unless ($addr || $self->param('username') ne '') {
      $self->redirect_to('billing_group', id => $self->param('id'));
    }
  }
  my $password = $self->param('password');
  if ($password eq '') {
    my @chars = ('a'..'z', 'A'..'Z', 0..9);
    $password = join '', map $chars[rand @chars], 0..15;
  }
  my $pai = $self->param('pai') =~ /^\d+$/ ? "'" . $self->param('pai') . "'" : 'NULL';

  if ($self->param('username') ne '') {
    my $q1 = <<SQL;
INSERT INTO subscriber (username, domain, password)
VALUES (?,(
  SELECT did
  FROM domain
  WHERE id = ?
),?)
RETURNING id;
SQL
    my $r1 = $db->query($q1 => ($self->param('username'),
                                $self->param('domain'),
                                $password));
    unless ($r1->rows > 0) {
      $self->render(template => 'exception');
    }
    my $q2 = <<SQL;
INSERT INTO customer_auth (customer_bg_id,
                           domain_id,
                           pai,
                           priority,
                           subscriber_id)
VALUES (?,?,$pai,?,?);
SQL
    $db->query($q2 => ($self->param('id'),
                       $self->param('domain'),
                       $self->param('priority'),
                       $r1->hash->{'id'}));
    $r1->finish;
  }
  if ($addr) {
    my $q3 = <<SQL;
INSERT INTO trusted
(src_ip, proto)
VALUES (?, 'any')
RETURNING id;
SQL
    my $r3 = $db->query($q3 => ($addr->addr()));
    unless ($r3->rows > 0) {
      $self->render(template => 'exception');
    }
    my $q4 = <<SQL;
INSERT INTO customer_auth (customer_bg_id,
                           domain_id,
                           pai,
                           priority,
                           trusted_id)
VALUES (?,?,$pai,?,?);
SQL
    $db->query($q4 => ($self->param('id'),
                       $self->param('domain'),
                       $self->param('priority'),
                       $r3->hash->{'id'}));
    $r3->finish;
  }
  $self->redirect_to('billing_group', id => $self->param('id'));
}

sub mod_auth {
  my $self = shift;
  my $db = $self->pg->db;
  my $pai = $self->param('pai') =~ /^\d+$/ ? "'" . $self->param('pai') . "'" : 'NULL';
  my $q1 = <<SQL;
UPDATE customer_auth
SET pai = $pai,
    priority = ?
WHERE id = ?;
SQL
  my $r1 = $db->query($q1 => ($self->param('priority'),
                              $self->param('aid')));

  if ($self->param('username') ne '') {
    my $password = $self->param('password');
    if ($password eq '') {
      my @chars = ('a'..'z', 'A'..'Z', 0..9);
      $password = join '', map $chars[rand @chars], 0..15;
    }
    my $q2 = <<SQL;
UPDATE subscriber
SET password = ?
WHERE username = ?
AND   domain = ?
SQL
    $db->query($q2 => ($password,
                       $self->param('username'),
                       $self->param('domain')));
  }
  $self->redirect_to('billing_group', id => $self->param('id'));
}

sub remove_auth {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1;
  if (defined $self->param('username') && $self->param('username') ne '') {
    $q1 = <<SQL;
DELETE FROM subscriber
WHERE id = (
  SELECT subscriber_id
  FROM customer_auth
  WHERE id = ?
);
SQL
  }
  elsif (defined $self->param('addr') && $self->param('addr') ne '') {
    $q1 = <<SQL
DELETE FROM trusted
WHERE id = (
  SELECT trusted_id
  FROM customer_auth
  WHERE id = ?
);
SQL
  }
  else {
    $self->redirect_to('billing_group', id => $self->param('id'));
  }
  say $q1;
  $db->query($q1 => ($self->param('aid')));
  my $q2 = "DELETE FROM customer_auth WHERE id = ?";
  $db->query($q2 => ($self->param('aid')));
  $self->redirect_to('billing_group', id => $self->param('id'));
}
1;
