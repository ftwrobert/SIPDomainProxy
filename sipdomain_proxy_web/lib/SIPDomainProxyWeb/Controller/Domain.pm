package SIPDomainProxyWeb::Controller::Domain;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(decode_json encode_json);

sub add_domain {
  my $self = shift;
  my $db = $self->pg->db;
  my $query1 = <<'SQL';
INSERT INTO domain (domain, did, last_modified)
VALUES (?,?,now());
SQL
  my $query2 = <<'SQL';
INSERT INTO domain_attrs (did, name, type, value, last_modified)
VALUES (?, ?, 2, ?, now()),
       (?, ?, 2, ?, now()),
       (?, ?, 2, ?, now()),
       (?, ?, 2, ?, now());
SQL
  my $r1 = $db->query($query1 => ($self->param('fqdn'), $self->param('fqdn')));
  my $r2 = $db->query($query2 => (
    $self->param('fqdn'), 'authtype', $self->param('pbx_type'),
    $self->param('fqdn'), 'pbx_addr', $self->param('addr'),
    $self->param('fqdn'), 'pbx_sipport', $self->param('sipport'),
    $self->param('fqdn'), 'domain', $self->param('fqdn'),
  ));
  unless ($r1->rows > 0 && $r2->rows > 0) {
    warn "Unable to add domain";
  }
  $self->redirect_to('domain');
}

sub domain {
  my $self = shift;
  $self->render_later;
  my $db = $self->pg->db;
  my $query = <<'SQL';
select *
from crosstab(
  'select domain.id, domain_attrs.name, domain_attrs.value
  from domain_attrs
  left join domain on domain_attrs.did=domain.did
  where (
       domain_attrs.name = ''authtype''
    or domain_attrs.name = ''domain''
    or domain_attrs.name = ''pbx_addr''
    or domain_attrs.name = ''pbx_sipport''
  )
  order by 1,2')
as domain_attrs(id integer,
                authtype character varying,
                domain character varying,
                pbx_addr character varying,
                pbx_sipport character varying);
SQL
  $db->query_p($query)->then(sub {
    $self->stash(domains => shift);
    $self->render(template => 'domain/domain');
  })->catch(sub {
    my $err = shift;
    warn "something went wrong: $err";
    $self->render(template => 'exception');
  })->wait;
}

sub remove_domain {
  my $self = shift;
  my $db = $self->pg->db;
  my $q1 = <<'SQL';
DELETE FROM domain
WHERE id = ?
RETURNING did;
SQL
  my $r1 = $db->query($q1 => ($self->param('id')));
  unless ($r1->rows > 0) {
    warn "Unable to delete domain";
    $self->render(template => 'exception');
  }
  my $q2 = <<'SQL';
DELETE FROM domain_attrs
WHERE did = ?;
SQL
  my $r2 = $db->query($q2 => ($r1->hash->{'did'}));
  unless ($r1->rows > 0 && $r2->rows > 0) {
    warn "Unable to delete attrs";
    $self->render(template => 'exception');
  }
  $self->redirect_to('domain');
}

1;
