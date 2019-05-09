package SIPDomainProxyWeb::Plugin::CollectionNextJSON;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON qw(encode_json);

# This Plugin adds the following helpers
#   * cnj_init()
#     - (re)Initialize the plugin to it's default state
#
#   * cnj_encoded()
#     - Returns a JSON encoded representation of the currect collection.
#
#   * cnj_data( 'name' [,'value'] [,'prompt'] );
#     - Returns a data "object"
#
#   * cnj_link( 'href', 'rel' [,'name'] [,'prompt'] [,'render'] );
#     - Returns a link "object"
#     - If passed, 'render' must be the literal strings 'link' or 'image'.
#
#   * cnj_tl_link( DATA_ARRAY_REF );
#     - Adds a link "object" to the top level links array.
#
#   * cnj_template( DATA_OBJECT_REF );
#     - Adds an "object" to the data array inside the template "object".
#
#   * cnj_template_title( 'title' );
#     - Adds a title property to the template "object".
#     !! This falls outside of the standard Collection.Next+JSON format. !!
#
#   * cnj_item( 'href' [,DATA_ARRAY_REF] [,LINKS_ARRAY_REF] [,'title'] );
#     - Adds an item "object" to the items array
#     !! The 'title' property falls outside of the standard !!
#     !! Collection.Next+JSON format.                       !!
#
#   * cnj_query( LINK_OBJECT_REF [,DATA_ARRAY_REF] );
#     - Adds a queries "object" to the queries array
#
#   * cnj_error( ['title'] [,'code'] [,'message'] );
#     - Adds an error "object" to the collection.
#
#   * cnj_uri( 'uri' );
#     - Set the URI of this collection.

my $collection_data = {
    'collection' => {'version' => '1.0', 'href' => 'URI'}
};

sub register {
  my $self   = shift;
  my $app    = shift;

  $app->helper(
    cnj_data => sub {
      my $c = shift;
      return prep_data(@_);
    }
  );

  $app->helper(
    cnj_encoded => sub {
      return encode_json $collection_data;
    }
  );

  $app->helper(
    cnj_error => sub{
      my $c = shift;
      return add_error(@_);
    }
  );

  $app->helper(
    cnj_init => sub {
      $collection_data = {
          'collection' => {'version' => '1.0', 'href' => 'URI'}
      };
      return 1;
    }
  );

  $app->helper(
    cnj_item => sub{
      my $c = shift;
      return add_item(@_);
    }
  );

  $app->helper(
    cnj_link => sub {
      my $c = shift;
      return prep_link(@_);
    }
  );

  $app->helper(
    cnj_tl_link => sub {
      my $c = shift;
      return add_tl_link(@_);
    }
  );

  $app->helper(
    cnj_query => sub{
      my $c = shift;
      return add_query(@_);
    }
  );

  $app->helper(
    cnj_template => sub {
      my $c = shift;
      return mod_template(@_);
    }
  );

  $app->helper(
    cnj_template_title => sub {
      my $c = shift;
      return mod_template_title(@_);
    }
  );

  $app->helper(
    cnj_uri => sub {
      my $c = shift;
      return set_uri(@_);
    }
  );
}

sub add_error{
  my ($title, $code, $message) = @_;
  say $title;
  $title   = (is_type($title,   'SCALAR')) ? $title   : '';
  $code    = (is_type($code,    'SCALAR')) ? $code    : '';
  $message = (is_type($message, 'SCALAR')) ? $message : '';
  $collection_data->{'collection'}->{'error'} = {'title'   => $title,
                                                 'code'    => $code,
                                                 'message' => $message};
  return 1;
}

sub add_item{
  my ($href, $data, $links, $title) = @_;
  if(is_type($href, 'SCALAR')){
    # We should probably verify that $href is a valid URI... FIXME
    my $item = {'href' => $href};
    if(is_type($data, 'ARRAY')){
      $item->{'data'} = $data;
    }
    if(is_type($links, 'ARRAY')){
      $item->{'links'} = $links;
    }
    if(is_type($title, 'SCALAR')){
      $item->{'title'} = $title;
    }
    push @{ $collection_data->{'collection'}->{'items'} }, $item;
    return 1;
  }
  return 0;
}

sub add_query{
  my ($link, $data) = @_;
  if(is_type($link, 'HASH')){
    if(is_type($data, 'ARRAY')){
      $link->{'data'} = $data;
    }
    delete $link->{'render'} if exists $link->{'render'};
    push @{ $collection_data->{'collection'}->{'queries'} }, $link;
    return 1;
  }
  return 0;
}

sub add_tl_link{
  my $link = shift;
  if(is_type($link, 'HASH')){
    push @{ $collection_data->{'collection'}->{'links'} }, $link;
    return 1;
  }
  return 0;
}

sub is_type{
  my $var = shift;
  my $type = shift;
  return 0 unless defined $var and defined $type;
  return 1 if ref \$var eq $type or ref $var eq $type;
  return 0;
}

sub mod_template{
  my $data = shift;
  if(is_type($data, 'HASH')){
    push @{ $collection_data->{'collection'}->{'template'}->{'data'} }, $data;
    return 1;
  }
  return 0;
}

sub mod_template_title {
  my $data = shift;
  if(is_type($data, 'SCALAR')){
    $collection_data->{'collection'}->{'template'}->{'title'} = $data;
    return 1;
  }
  return 0;
}

sub prep_data{
  # name = required; value, prompt = optional
  my ($name, $value, $prompt) = @_;
  $name   = is_type($name,   'SCALAR') ? $name   :  0;
  $value  = is_type($value,  'SCALAR') ? $value  : '';
  $prompt = is_type($prompt, 'SCALAR') ? $prompt : '';
  if($name){

    return {'name' => $name, 'value' => $value, 'prompt' => $prompt};
  }
  return 0;
}

sub prep_link{
  # href, rel = required; name, render, prompt = optional
  # render must be: 'image' || 'link', if absent, assume 'link'
  my ($href, $rel, $name, $prompt, $render) = @_;
  $href   = is_type($href,   'SCALAR') ? $href   : 0 ;
  $rel    = is_type($rel,    'SCALAR') ? $rel    : 0 ;
  $name   = is_type($name,   'SCALAR') ? $name   : '';
  $render = is_type($render, 'SCALAR') ? $render : '';
  $prompt = is_type($prompt, 'SCALAR') ? $prompt : '';
  $render = ($render eq 'image') ? 'image' : 'link';
  if($href and $rel){
    return {'href'   => $href,
            'rel'    => $rel,
            'name'   => $name,
            'render' => $render,
            'prompt' => $prompt};
  }
  return 0;
}

sub set_uri{
  my $uri = shift;
  if (is_type($uri, 'SCALAR'))
  {
    $collection_data->{'collection'}->{'href'} = $uri;
    return 1;
  }
  return 0;
}

1;

__END__

=pod

=head1 NAME

SIPDomainProxyWeb::Plugin::CollectionNextJSON;

=head1 VERSION

Version 20160818

=head1 SYNOPSIS

Provides helpers to assist in creating and validating the Collection.next+JSON
  document format.
  L<Collection+JSON Spec|https://github.com/collection-json/spec>
  L<Collection.next+JSON Assignement|https://www.iana.org/assignments/media-types/application/vnd.collection.next+json>
  L<Collection.next+JSON Spec|http://code.ge/media-types/collection-next-json/>

    # Controller
    sub example {
      my $self = shift;
      # Create and return a data object for an item.
      my $d1 = $this->cnj_data('name1', 'value1');
      my $d2 = $this->cnj_data('name2', 'value2');
      # Obtain our current URL
      my $href = $this->url_for('current')->to_string;
      # Add an item to the collection.
      $this->cnj_item($href, [$d1, $d2]);
      # retreive the Collection.next+JSON encoded document.
      my $data = $this->cnj_encoded();
      # Pass it to render, FIXME (you must declare the format type before hand)
      $self->render(data => $data, format = 'cnjson');
    }

=head1 HELPERS

# This Plugin adds the following helpers
#   * cnj_init()
#     - (re)Initialize the plugin to it's default state
#
#   * cnj_encoded()
#     - Returns a JSON encoded representation of the currect collection.
#
#   * cnj_data( 'name' [,'value'] [,'prompt'] );
#     - Returns a data "object"
#
#   * cnj_link( 'href', 'rel' [,'name'] [,'prompt'] [,'render'] );
#     - Returns a link "object"
#     - If passed, 'render' must be the literal strings 'link' or 'image'.
#
#   * cnj_tl_link( DATA_ARRAY_REF );
#     - Adds a link "object" to the top level links array.
#
#   * cnj_template( DATA_OBJECT_REF );
#     - Adds an "object" to the data array inside the template "object".
#
#   * cnj_template_title( 'title' );
#     - Adds a title property to the template "object".
#     !! This falls outside of the standard Collection.Next+JSON format. !!
#
#   * cnj_item( 'href' [,DATA_ARRAY_REF] [,LINKS_ARRAY_REF] [,'title'] );
#     - Adds an item "object" to the items array
#     !! The 'title' property falls outside of the standard !!
#     !! Collection.Next+JSON format.                       !!
#
#   * cnj_query( LINK_OBJECT_REF [,DATA_ARRAY_REF] );
#     - Adds a queries "object" to the queries array
#
#   * cnj_error( ['title'] [,'code'] [,'message'] );
#     - Adds an error "object" to the collection.
#
#   * cnj_uri( 'uri' );
#     - Set the URI of this collection.

=head1 TODO
* Additional data validation when DATA_ARRAY_REF, DATA_OBJECT_REF,
    LINKS_ARRAY_REF, LINK_OBJECT_REF are submitted to cnj_template, cnj_item
    and cnj_query.
* Automatically create the 'cnjson' format type when the plugin is included.

=cut
