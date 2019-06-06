package SIPDomainProxyWeb::Controller::BillingGroup;
use Mojo::Base 'Mojolicious::Controller';

sub add_billing_group {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1 = "INSERT INTO customer_bg (customer_id, descr, pai) VALUES (?,?,?)";
  my $r1 = $db->query($q1 => ($self->param('id'),
                              $self->param('descr'),
                              $self->param('pai')));
  unless ($r1->rows > 0) {
    warn "Unable to add billing group";
    $self->render(template => 'exception');
  }
  $self->redirect_to('customer', id => $self->param('id'));
}

sub billing_group {
  my $self = shift;
  my $db = $self->pg->db;

  my $q1 = <<'SQL';
SELECT customer.id as customer_id,
       customer.descr as customer_descr,
       customer_bg.id as customer_bg_id,
       customer_bg.descr as customer_bg_descr,
       customer_bg.pai as customer_bg_pai
FROM customer_bg
LEFT JOIN customer ON customer_bg.customer_id=customer.id
WHERE customer_bg.id = ?;
SQL
  my $r1 = $db->query($q1 => ($self->param('id')));
  unless ($r1->rows > 0) {
    warn "Unable to retrieve billing group description";
    $self->render(template => 'exception');
  }
  $self->stash(billing_group => $r1->hash);
  $r1->finish;

  my $q2 = <<'SQL';
SELECT domain.id, domain.did
FROM domain
LEFT JOIN domain_attrs ON domain.did=domain_attrs.did
WHERE domain_attrs.name = 'authtype'
AND   domain_attrs.value = 'registration';
SQL
  my $r2 = $db->query($q2);
  $self->stash(domains => $r2);

  my $q3 = <<'SQL';
SELECT prefix
FROM did_numbers
WHERE customer_bg_id = ?
ORDER BY prefix;
SQL
  my $r3 = $db->query($q3 => ($self->param('id')));
  $self->stash(prefixes => $r3);

  my $q4 = <<SQL;
SELECT customer_auth.priority,
       customer_auth.id,
       customer_auth.pai,
       subscriber.username,
       subscriber.password,
       trusted.src_ip,
       domain.domain,
       CASE WHEN subscriber.username IS NULL
         THEN 'trusted'
         ELSE 'digest'
       END as type
FROM customer_auth
LEFT JOIN customer_bg ON customer_auth.customer_bg_id=customer_bg.id
LEFT JOIN subscriber ON customer_auth.subscriber_id=subscriber.id
LEFT JOIN trusted ON customer_auth.trusted_id=trusted.id
LEFT JOIN domain ON customer_auth.domain_id=domain.id
WHERE customer_bg.id = ?
ORDER BY customer_auth.priority,
         CASE WHEN subscriber.username IS NULL
           THEN 1
           ELSE 0
         END,
         customer_auth.id
SQL
  my $r4 = $db->query($q4 => $self->param('id'));
  $self->stash(authorizations => $r4);
  $self->render(template => 'customer_provisioning/billing_group');

}

sub mod_billing_group {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1 = "UPDATE customer_bg SET descr = ?, pai = ? WHERE id = ?";
  my $r1 = $db->query($q1 => ($self->param('descr'),
                              $self->param('pai'),
                              $self->param('id')));
  unless ($r1->rows > 0) {
    warn "Unable to update billing group name";
    $self->render(template => 'exception');
  }
  $self->redirect_to('billing_group', id => $self->param('id'));
}

sub remove_billing_group {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1 = "SELECT customer_id FROM customer_bg WHERE id = ?";
  my $r1 = $db->query($q1 => ($self->param('id')));
  unless ($r1->rows > 0) {
    warn "Unable to find customer from billing group";
    $self->render(template => 'exception');
  }
  my $q2 = "DELETE FROM customer_bg WHERE id = ?";
  my $r2 = $db->query($q2 => ($self->param('id')));
  unless ($r2->rows > 0) {
    warn "Unable to remove billing group";
    $self->render(template => 'exception');
  }
  my $cid = $r1->hash->{customer_id};
  $self->redirect_to('customer', id => $cid);
}

1;
