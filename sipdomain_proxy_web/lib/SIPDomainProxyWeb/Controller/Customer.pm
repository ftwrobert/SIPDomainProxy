package SIPDomainProxyWeb::Controller::Customer;
use Mojo::Base 'Mojolicious::Controller';

sub add_customer {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1 = "INSERT INTO customer (descr) VALUES (?);";
  my $r1 = $db->query($q1 => ($self->param('descr')));
  unless ($r1->rows > 0) {
    warn "Unable to add customer";
    $self->render(template => 'exception');
  }
  $self->redirect_to('customers');
}

sub customers {
  my $self = shift;
  $self->render_later;
  my $db = $self->pg->db;
  my $query = "SELECT id, descr FROM customer;";
  $db->query_p($query)->then(sub {
    $self->stash(customers => shift);
    $self->render(template => 'customer_provisioning/customers');
  })->catch(sub {
    my $err = shift;
    warn "something went wrong: $err";
    $self->render(template => 'exception');
  })->wait;
}

sub customer {
  my $self = shift;
  $self->render_later;
  my $db = $self->pg->db;
  my $q1 = "SELECT descr FROM customer WHERE id = ?";
  my $r1 = $db->query($q1 => ($self->param('id')));
  unless ($r1->rows > 0) {
    warn "Unable to retrieve customer description";
    $self->render(template => 'exception');
  }
  $self->stash(descr => $r1->hash->{descr});
  $r1->finish;
  my $q2 = "SELECT id, descr, pai FROM customer_bg WHERE customer_id = ?";
  $db->query_p($q2 => ($self->param('id')))->then(sub {
    $self->stash(billing_groups => shift);
    $self->stash(id => $self->param('id'));
    $self->render(template => 'customer_provisioning/customer');
  })->catch(sub {
    my $err = shift;
    warn "something went wrong: $err";
    $self->render(template => 'exception');
  })->wait;
}

sub mod_customer {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1 = "UPDATE customer SET descr = ? WHERE id = ?";
  my $r1 = $db->query($q1 => ($self->param('descr'),
                              $self->param('id')));
  unless ($r1->rows > 0) {
    warn "Unable to update customer name";
    $self->render(template => 'exception');
  }
  $self->redirect_to('customer', id => $self->param('id'));
}

sub remove_customer {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1 = "DELETE FROM customer WHERE id = ?";
  my $r1 = $db->query($q1 => ($self->param('id')));
  unless ($r1->rows > 0) {
    warn "Unable to delete customer";
    $self->render(template => 'exception');
  }
  $self->redirect_to('customers');
}

1;
