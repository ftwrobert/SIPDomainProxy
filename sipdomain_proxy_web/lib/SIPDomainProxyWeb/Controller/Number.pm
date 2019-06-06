package SIPDomainProxyWeb::Controller::Number;
use Mojo::Base 'Mojolicious::Controller';

sub add_tns {
  my $self = shift;
  my $db = $self->pg->db;
  my $pai = $self->param('pai') =~ /^\d+$/ ? "'" . $self->param('pai') . "'" : 'NULL';
  my @values = ();
  my @prefixes = parse_tns($self->param('prefixes'));
  unless (@prefixes) {
    $self->redirect_to('billing_group', id => $self->param('id'));
  }
  foreach (@prefixes) {
    my $num = $_;
    push @values, '(' . $self->param('id') . ", '$_', $pai)";
  }
  my $q1 = "INSERT INTO did_numbers (customer_bg_id, prefix, pai) VALUES "
         . join (', ', @values)
         . 'ON CONFLICT (prefix) DO NOTHING;';
  my $r1 = $db->query($q1);
  unless ($r1->rows > 0) {
    warn "Unable to add tns";
  }
  $self->redirect_to('billing_group', id => $self->param('id'));
}

sub remove_tns {
  my $self = shift;
  my $db = $self->pg->db;
  my @values = ();
  my @prefixes = parse_tns($self->param('prefixes'));
  unless (@prefixes) {
    $self->redirect_to('billing_group', id => $self->param('id'));
  }
  foreach (@prefixes) {
    push @values, ' prefix = \'' . $_ . '\' ';
  }
  my $ors = join ('or', @values);
  my $q1 = <<SQL;
DELETE FROM did_numbers
WHERE customer_bg_id = ?
AND (
  $ors
);
SQL
  $db->query($q1 => $self->param('id'));
  $self->redirect_to('billing_group', id => $self->param('id'));
}

sub parse_tns {
  my $rangestr = shift;
  my (@numbers, $first, $count, $last);
  $rangestr = join '', grep(/[-+,\d\r\n ]/, $rangestr);
  unless ($rangestr =~
                  /^(\d{10}(-\d{10}|\+\d{1,3})?)([,\r\n ]+\d{10}(-\d{10}|\+\d{1,3})?)*$/
          ) {
    say 'Invalid range paramater';
    return undef;
  }
  foreach my $range (split /[,\r\n ]+/, $rangestr) {
    if ($range =~ /^\d{10}$/) {
      push @numbers, $range;
      next;
    }
    if ($range =~ /^\d{10}-\d{10}$/) {
      my ($first, $last) = split '-', $range;
      push @numbers, $first .. $last;
      undef $first;
      undef $last;
      next;
    }
    if ($range =~ /\d{10}\+\d{1,3}$/) {
      ($first, $count) = split /\+/, $range;
      for ( my $i = 0; $i < $count; $i++) {
        push @numbers, $first;
        $first++;
      }
      undef $first;
      undef $count;
    }
  }
  my %seen = ();
  my @unique = grep { ! $seen{ $_ }++ } @numbers;
  return @unique;
}

1;
