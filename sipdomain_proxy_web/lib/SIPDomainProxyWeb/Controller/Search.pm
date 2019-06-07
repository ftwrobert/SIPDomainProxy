package SIPDomainProxyWeb::Controller::Search;
use Mojo::Base 'Mojolicious::Controller';

sub search {
  my $self = shift;
  my $db = $self->pg->db;
  my $searched = $self->param('search');
  $self->stash(searched => $self->param('search'));
  if ($self->param('search') eq '') {
    my $q3 = <<SQL;
SELECT '' as customer_id,
       '' as customer_descr,
       '' as customer_bg_id,
       '' as customer_bg_descr,
       '' as prefix
SQL
    my $r3 = $db->query($q3);
    $self->stash(results => $r3);
    $self->render('search/search');
  }
  elsif ($searched =~ /\A\d+\Z/) {
    # Numbers only, we might be searching for a phone number.
    my $q1 = <<SQL;
SELECT customer.id as customer_id,
       customer.descr as customer_descr,
       customer_bg.id as customer_bg_id,
       customer_bg.descr as customer_bg_descr,
       did_numbers.prefix as prefix
FROM did_numbers
LEFT JOIN customer_bg ON did_numbers.customer_bg_id=customer_bg.id
LEFT JOIN customer ON customer_bg.customer_id=customer.id
WHERE did_numbers.id IN (
  SELECT id
  FROM did_numbers
  WHERE prefix::text LIKE ?
)
ORDER BY customer_descr, customer_bg_descr, prefix;
SQL
    $searched = '%' . $searched . '%';
    my $r1 = $db->query($q1, $searched);
    $self->stash(results => $r1);
    $self->render('search/search');
  }
  else {
  # Look for customer accounts and billing groups
  my @words    = split /\s/, $searched;
  my $numWords = @words;
  my $ilike    = '';
  foreach ( my $i = 0 ; $i < $numWords ; $i++ ) {

    # Will use to add to our queries
    $ilike .= 'descr ILIKE ?' if $i == 0;
    $ilike .= ' and descr ILIKE ?' if $i > 0;

    # Each of the "word" items, needs to be pre and post fixed with %
    $words[$i] = '%' . $words[$i] . '%';
  }
    # Query for our customer matches
    my $q2 = <<SQL;
SELECT customer.id as customer_id,
       customer.descr as customer_descr,
       customer_bg.id as customer_bg_id,
       customer_bg.descr as customer_bg_descr,
       '' as prefix
FROM customer
LEFT JOIN customer_bg ON customer.id=customer_bg.customer_id
WHERE (
  customer.id IN (
    SELECT DISTINCT(id)
    FROM customer
    WHERE $ilike
  )
)
OR (
  customer_bg.id IN (
    SELECT DISTINCT(id)
    FROM customer_bg
    WHERE $ilike
  )
)
ORDER BY customer_descr, customer_bg_descr, prefix;
SQL
    say $q2;
    my $r2 = $db->query($q2, @words, @words);
    $self->stash(results => $r2);
    $self->render('search/search');
  }
  return 1;
}

1;
